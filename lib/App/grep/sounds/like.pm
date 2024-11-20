package App::grep::sounds::like;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use AppBase::Grep;
use List::Util qw(min);
use Perinci::Sub::Util qw(gen_modified_sub);
use Text::Levenshtein::XS;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

gen_modified_sub(
    output_name => 'grep_sounds_like',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Print lines with words that sound like to the specified word',
    description => <<'MARKDOWN',

This is a grep-like utility that greps for text in input that has word(s) that
sound like the specified text. By default uses the `Metaphone` algorithm.

MARKDOWN
    remove_args => [
        'regexps',
        'pattern',
        'dash_prefix_inverts',
        'all',
    ],
    add_args    => {
        word => {
            summary => 'Word to compare',
            schema => 'str*',
            req => 1,
            pos => 0,
            tags => ['category:filtering'],
        },
        algo => {
            summary => 'Phonetic algorithm to use, should be a module under `Text::Phonetic::` without the prefix',
            schema => 'perl::modname*',
            default => 'Metaphone',
            completion => sub {
                require Complete::Module;
                my %args = @_;
                Complete::Module::complete_module(word => $args{word}, ns_prefix => 'Text::Phonetic::');
            },
            tags => ['category:filtering'],
        },
        files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'file',
            schema => ['array*', of=>'filename*'],
            pos => 1,
            slurpy => 1,
        },

        # XXX recursive (-r)
    },
    modify_meta => sub {
        my $meta = shift;
        $meta->{examples} = [
            {
                summary => 'Show lines that have word(s) similar to "orange"',
                'src' => q([[prog]] orange file.txt),
                'src_plang' => 'bash',
                'test' => 0,
                'x.doc.show_result' => 0,
            },
        ];

        $meta->{links} = [
        ];
    },
    output_code => sub {
        my %args = @_;
        my ($fh, $file);

        my @files = @{ delete($args{files}) // [] };

        my $show_label = 0;
        if (!@files) {
            $fh = \*STDIN;
        } elsif (@files > 1) {
            $show_label = 1;
        }

        $args{_source} = sub {
          READ_LINE:
            {
                if (!defined $fh) {
                    return unless @files;
                    $file = shift @files;
                    log_trace "Opening $file ...";
                    open $fh, "<", $file or do {
                        warn "grep-sounds-like: Can't open '$file': $!, skipped\n";
                        undef $fh;
                    };
                    redo READ_LINE;
                }

                my $line = <$fh>;
                if (defined $line) {
                    return ($line, $show_label ? $file : undef);
                } else {
                    undef $fh;
                    redo READ_LINE;
                }
            }
        };

        my $phonetic_mod = "Text::Phonetic::" . ($args{algo} // 'Metaphone');
        (my $phoneitc_mod_pm = "$phonetic_mod.pm") =~ s!::!/!g;
        require $phoneitc_mod_pm;
        my $phonetic_obj = $phonetic_mod->new;

        $args{_filter_code} = sub {
            my ($line, $fargs, $ansi_highlight_seq) = @_;

            my @words = $line =~ /(\w+)/g;
            my @matching_words;
            for (@words) { push @matching_words, $_ if $phonetic_obj->compare($_, $args{word}) }

            return [0] unless @matching_words;
            my $re = join("|", map {quotemeta($_)} @matching_words);

            (my $highlighted_line = $line) =~ s/($re)/$ansi_highlight_seq$1\e[0m/g;
            [1, $highlighted_line];
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:
