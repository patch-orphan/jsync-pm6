module t::Bridge;

use JSYNC;
use YAML;

sub load_jsync ($this) {
    return JSYNC::load($this.value);
}

sub dump_jsync ($this) {
    return JSYNC::dump($this.value);
}

sub load_yaml ($this) {
    return YAML::load($this.value);
}

sub dump_yaml ($this) {
    return YAML::dump($this.value);
}

sub chomp ($this) {
    my $str = $this.value;
    $str.=chomp;
    return $str;
}

sub eval_perl ($this) {
    return eval $this.value;
    CATCH {
        return "$!";
    }
}
