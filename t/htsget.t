# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
use strict;
use warnings;

use FindBin qw($Bin);
use File::Spec;
use Test::More;
use Test::Mojo;

my $config = File::Spec->catfile($Bin, qw/data test.json/);
$ENV{MOJO_CONFIG} = $config;

my $t = Test::Mojo->new('BasicHtsget::App');

my $generate_url = sub {
  my ($path, $params) = @_;
  my $url = $t->ua->server->url();
  $url->path($path);
  $url->query(%{$params}) if $params;
  return $url;
};

my $url_to_json = sub {
  my ($path, $params) = @_;
  my $url = $generate_url->($path, $params);
  my $expected = {
    'htsget' => {
      'format' => 'VCF',
      'urls' => [
        {
          'headers' => {
            'Accept' => 'application/vnd.ga4gh.vcf'
          },
          'url' => $url->to_abs()
        }
      ]
    }
  };
  return $expected;
};

# Full length VCF retrieval
{
  my $expected = $url_to_json->('/variants/mini/vcf');
  $t->get_ok('/variants/mini', { Accept => 'appliction/json'})
    ->status_is(200)
    ->json_is($expected)->or(sub {diag explain $t->tx->res->json;});

  my $url = $generate_url->('/variants/mini/vcf');
  $t->get_ok($url->to_string())
    ->status_is(200)
    ->content_like(qr/.+IV\s390453\ss04-390450.+/msi);
}

# Partial retreival
{
  my $params = { referenceName => 'IV', start => 0, end => 100 };
  my $expected = $url_to_json->('/variants/local_scer/vcf', $params);
  $t->get_ok('/variants/local_scer?referenceName=IV&start=0&end=100', { Accept => 'appliction/json'})
    ->status_is(200)
    ->json_is('/htsget/format' => 'VCF')
    ->json_is('/htsget/urls/0/headers/Accept' => 'application/vnd.ga4gh.vcf')
    ->json_like('/htsget/urls/0/url' => qr|.+(?:/variants/local_scer/vcf\?.*?referenceName=IV).+|);
}

done_testing();