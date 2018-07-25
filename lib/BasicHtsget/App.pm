package BasicHtsget::App;

use Mojo::Base 'Mojolicious';
use Scalar::Util qw/looks_like_number/;

our $API_VERSION = '1.1.0';
our $API_VND = 'vnd.ga4gh.htsget.v'.$API_VERSION;
our $VCF_MIME = 'application/vnd.ga4gh.vcf';

sub startup {
	my ($self) = @_;

  $self->moniker('basic-htsget');

	# Configure hypnotoad
	if(exists $ENV{APP_PID_FILE}) {
		$self->config(
			hypnotoad => {
				proxy => 1,
				pid_file => $ENV{APP_PID_FILE},
			}
		);
	}

	if(exists $ENV{APP_LOG_FILE}) {
		my $loglevel = $ENV{APP_LOG_LEVEL} || 'warn';
		$self->log(Mojo::Log->new(path => $ENV{APP_LOG_FILE}, level => $loglevel ));
	}

	if(exists $ENV{APP_ACCESS_LOG_FILE}) {
		my $logformat = $ENV{APP_ACCESS_LOG_FORMAT} || 'combinedio';
		$self->plugin(AccessLog => log => $ENV{APP_ACCESS_LOG_FILE}, format => $logformat);
	}

  $self->plugin('JSONConfig');

	$self->cors();
  $self->install_helpers();
  $self->custom_content_types();

  # Used to capture requests for tbi and csi indexes
  $self->hook(around_dispatch => sub {
    my ($next, $c) = @_;
    my $path = $c->req->url->to_abs->to_string;
    if($path =~ /.+\.((?:tb|cs)i)$/) {
      return $c->render(text => "Server has no ${1} indexes to provide", status => 404);
    }
    $next->();
  });

	# Route commands through the application
	my $r = $self->routes;

	# Things that go to a controller
  $r->get('/variants/:id')->to(controller => 'hts', action => 'htsget');
  $r->get('/variants/:id/vcf')->to(controller => 'hts', action => 'getvcf')->name('getvcf');

  return;
}

sub cors {
  my ($self) = @_;
  #Sledgehammer; support CORS on all URL requests by intercepting everything, sniffing for OPTIONS and then
  #choosing to move onto the next action or bailing out with a CORS response
  $self->hook( around_dispatch => sub {
    my $next = shift;
    my $c = shift;
    my $req = $c->req->headers();
    my $options_request = 0;
    if($req->origin) {
      my $resp = $c->res->headers();
      # If we have this we are in a pre-flight according to https://www.html5rocks.com/static/images/cors_server_flowchart.png
      if($c->req->method eq 'OPTIONS' && $req->header('access-control-request-method')) {
        $resp->header('Access-Control-Allow-Methods' => 'GET, OPTIONS');
        $resp->header('Access-Control-Max-Age' => 2592000);
        $resp->header('Access-Control-Allow-Headers' => 'Content-Type, Authorization, X-Requested-With, api_key, Range');
        $options_request = 1;
      }
      else {
        $resp->header('Access-Control-Expose-Headers' => 'Cache-Control, Content-Language, Content-Type, Expires, Last-Modified, Pragma');
      }

      $resp->header('Access-Control-Allow-Origin' => $req->header('Origin') );
    }

    if($options_request) {
      $c->render(text => q{}, status => 200);
    }
    else {
      $next->();
    }
  });
  return;
}

sub custom_content_types {
  my ($self) = @_;
  my $types = $self->types();
  $types->type(json => ["application/${API_VND}+json", 'application/json']);
  $types->type(vcf => $VCF_MIME);
  return;
}

sub install_helpers {
  my ($self) = @_;

  $self->helper( "has_id" => sub {
    my ($c, $id) = @_;
    return exists $c->config->{lookup}->{$id} ? 1 : 0;
  });

  $self->helper( "get_path" => sub {
    my ($c, $id) = @_;
    return $c->config->{lookup}->{$id};
  });

  $self->helper( "raise_error" => sub {
    my ($c, $error, $status, $message) = @_;
    return $c->render( json => {
      htsget => { error => $error, message => $message }
    }, status => $status );
  });

  $self->helper( "validate_int" => sub{
    my ($c, $int, $type) = @_;
    if(!looks_like_number($int)) {
      $c->raise_error('InvalidInput', 400, "${type} is not a number");
    }
    if(int($int) != $int) {
      $c->raise_error('InvalidInput', 400, "${type} is not an integer");
    }
  });

  $self->helper( "validate_coords" => sub{
    my ($c, $start, $end) = @_;
    $c->validate_int($start, 'start') if defined $start;
    $c->validate_int($end, 'end') if defined $end;
    if( ($start && $end) && ($start > $end)) {
      $c->raise_error('InvalidInput', 400, 'start is greater than end');
    }
  });

  $self->helper( "vcf_mime" => sub {
    return $VCF_MIME;
  });

  $self->helper( "bcftools_bin" => sub {
    my $c = shift @_;
    return exists $c->config->{bcftools} ? $c->config->{bcftools} : 'bcftools';
  })
}

1;