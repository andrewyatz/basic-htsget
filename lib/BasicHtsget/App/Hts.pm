package BasicHtsget::App::Hts;

use Mojo::Base 'Mojolicious::Controller';

sub htsget {
  my ($self) = @_;
  my $id = $self->param('id');
  my $reference_name = $self->param('referenceName');
  my $start = $self->param('start');
  my $end = $self->param('end');
  my $format = $self->param('format');

  if(! $reference_name) {
    return $self->raise_error('InvalidInput', 400, 'This server requires you to specify a referenceName');
  }
  if(!$self->has_id($id)) {
    return $self->raise_error('NotFound', 404, 'Identifier is unknown');
  }
  if($format && $format != 'VCF') {
    return $self->raise_error('UnsupportedFormat', 400, 'Unsupported format. Only "VCF" is understood');
  }
  $self->validate_coords($start, $end);
  $self->_check_reference_name($id, $reference_name);

  # Build response
  my %params = (referenceName => $reference_name, start => ($start+1), end => $end);
  my $resp = {
    htsget => {
      format => "VCF",
      urls => [
        {
          "url" => $self->url_for('getvcf', id => $id )->query(%params)->to_abs(),
          headers => {
            'Accept' => $self->vcf_mime(),
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
	my $range = sprintf('%s:%d-%d', $reference_name, $start, $end);
	my $location = $self->get_path($id);
	$self->res->headers->content_type($self->vcf_mime());
  my $bin = $self->bcftools_bin();
	open my $fh, "${bin} view --output-type v --regions ${range} ${location}|"  or die "Cannot execute ${bin}";
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
  return exists $lookup->{$id} ? 1 : 0;
}

sub _reference_name_lookup {
  my ($self, $id) = @_;
  my $location = $self->get_path($id);
  my $bin = $self->bcftools_bin();
  open my $fh, "${bin} index --stats ${location}|"  or die "Cannot execute ${bin}";
  my %lookup;
  while(my $line = <$fh>) {
    my ($reference_name) = split(/\s+/, $line);
    $lookup{$reference_name} = 1;
  }
  return \%lookup;
}

1;