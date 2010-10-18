
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Module::Build' => '0.3601'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Use Data::Dump to produce dumps that fit in one line',
  'dist_author' => [
    'Steven Haryanto <stevenharyanto@gmail.com>'
  ],
  'dist_name' => 'Data-Dump-OneLine',
  'dist_version' => '0.01',
  'license' => 'perl',
  'module_name' => 'Data::Dump::OneLine',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Data::Dump' => '1.17',
    'perl' => '5.010'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
