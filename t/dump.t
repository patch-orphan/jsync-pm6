use t::TestJSYNC tests => 1;

spec_file 't/jsync-yaml.tml';

filters {
    yaml => ['load_yaml', 'dump_jsync'],
    jsync => 'chomp',
};

run_is yaml => 'jsync';