package BasicHtsget::App::Hts;

use Mojo::Base 'Mojolicious::Controller';

sub htsget {
  my ($self) = @_;
  my $id = $self->param('id');
  my $reference_name = $self->param('referenceName');
  my $start = $self->param('start');
  my $end = $self->param('end');
  my $format = $self->param('format');

  my %params;
  if(!$self->has_id($id)) {
    return $self->raise_error('NotFound', 404, 'Identifier is unknown');
  }
  if($format && $format != 'VCF') {
    return $self->raise_error('UnsupportedFormat', 400, 'Unsupported format. Only "VCF" is understood');
  }

  if(defined $reference_name) {
    if($self->_check_reference_name($id, $reference_name)) {
      $params{referenceName} = $reference_name;
    }
    else {
      return $self->raise_error('InvalidRange', 400, 'Given referenceName '.$reference_name.' cannot be found');
    }
  }

  if(defined $start) {
    if(!defined $reference_name) {
      return $self->raise_error('InvalidInput', 400, 'Start has been specified but referenceName has not been given');
    }
    $self->validate_coords($start, $end);
    $params{start} = ($start+1);
    $params{end} = $end;
  }

  # Build response
  my %auth;
  if($self->stash('token')) {
    $auth{'Authorization'} = 'Bearer '.$self->stash('token');
  }
  my $url;
  if(%params) {
    $url = $self->url_for('getvcf', id => $id )->query(%params)->to_abs();
  }
  else {
    $url = $self->url_for('getvcf', id => $id )->to_abs(),
  }
  my $resp = {
    htsget => {
      format => "VCF",
      urls => [
        {
          "url" => $url,
          headers => {
            'Accept' => $self->vcf_mime(),
            %auth,
          },
        }
      ]
    }
  };

  return $self->render(json => $resp);
}

sub getvcf {
  my ($self) = @_;
	my $id = $self->param('id');
	my $reference_name = $self->param('referenceName');
	my $start = $self->param('start');
	my $end = $self->param('end');
  my $range = q{};
  if($id) {
    if($start) {
      $range = sprintf('--regions %s:%d-%d', $reference_name, $start, $end);
    }
    elsif($reference_name) {
      $range = "--regions ${reference_name}";
    }
  }
	my $location = $self->get_path($id);
	$self->res->headers->content_type($self->vcf_mime());
  my $bin = $self->bcftools_bin();
  my $command = "${bin} view --output-type v ${range} ${location}|";
	open my $fh, $command or die "Cannot execute ${bin}: $!";
	my $drain;
	$drain = sub {
		my $c = shift;
		my $row = <$fh>;
    # Skip all bcftools_view headers
    while($row && $row =~ /^##bcftools_view/) {
      $row = <$fh>;
    }
		if($row) {
			$c->write($row, $drain);
		}
    else {
			close $fh;
			$c->write('');
		}
	};
	$self->$drain;
}

sub _check_reference_name {
  my ($self, $id, $reference_name) = @_;
  my $lookup = $self->_reference_name_lookup($id);
  return exists $lookup->{$reference_name} ? 1 : 0;
}

sub _reference_name_lookup {
  my ($self, $id) = @_;
  my $location = $self->get_path($id);
  my $bin = $self->bcftools_bin();
  my $command = "${bin} index --stats ${location}|";
  open my $fh, $command  or die "Cannot execute ${bin}: $!";
  my %lookup;
  while(my $line = <$fh>) {
    my ($reference_name) = split(/\s+/, $line);
    $lookup{$reference_name} = 1;
  }
  return \%lookup;
}

1;