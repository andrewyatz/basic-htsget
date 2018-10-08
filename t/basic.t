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
$t->get_ok('/')->status_is(200);
$t->get_ok('/index')->status_is(200);
$t->get_ok('/ping')->status_is(200)->content_is('Ping');