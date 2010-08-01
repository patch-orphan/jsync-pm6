use TestML::Runner::TAP;

TestML::Runner::TAP.new(
    document => 'roundtrip.tml',
    bridge   => 't::Bridge',
).run();
