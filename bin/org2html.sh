#!/usr/bin/env bash
set -u

export cName=org2html.sh
export gpDebug=${gpDebug:-0}
export Tmp=${Tmp:-"/tmp/$USER/$cName"}
export cBin
export gpFileIn=""
export gpFileOut=""
export gpSep=0
export cTidyHtml="tidy -q -i -w 78 -asxhtml --break-before-br yes --indent-attributes yes --indent-spaces 2 --tidy-mark no --vertical-space no"

# ========================================
# Functions

# --------------------------------
fUsage() {
    local pStyle="$1"
    local tProg=""
    
    case $pStyle in
        short | usage)
            tProg=pod2usage
            ;;
        long | text)
            tProg=pod2text
            ;;
        html)
            tProg="pod2html --title=$cName"
            ;;
        md)
            tProg=pod2markdown
            ;;
        man)
            tProg=pod2man
            ;;
        *)
            tProg=pod2text
            ;;
    esac

    # Default to pod2text if tProg does not exist
    if ! which ${tProg%% *} >/dev/null; then
        tProg=pod2text
    fi
    cat $cBin/$cName | $tProg | less
    exit 1
    
    cat <<\EOF >/dev/null
=pod

=for text ========================================

=for html <hr/>

=head1 NAME org2html.sh

Comvert FILE.org to FILE.html

=head1 SYNOPSIS

    org2html.sh [-s N] InFile.org [OutFile.html]
    org2html.sh -i InFile.org [-o OutFile.html] [-s N] 
    org2html.sh [-h] [-H pStyle]

=head1 DESCRIPTION

FILE.org will be converted to FILE.html. It has some fixes to the
"pandoc" conversion.

If the outputfile (FILE.html) is missing, then the InFile.org base
name will be used for the html file.

The -s option can be used to put hr tags in the output.

Before org2html.sh is run, all files in $Tmp are removed, unless
env. var. gpDebug is set and not 0.

See the SEE ALSO section for the required programs.

=head2 Replacements

    '+ ' - will be changed to <li>
    '- ' - will be regular paragraphs
           Also blank lines separate paragraphs
    '**** ' - will be replaced with <h4> (similarly for 5 and 6 *)
    '{.*}' - will be replaced with <cite>.*</cite>
    '[TBD.*] - will be replaced with <span class="tbd">[TBD.*]</span>
    '[TK.*] - will be replaced with <span class="tbd">[TK.*]</span>

=head1 OPTIONS

=over 4

=item B<-i FILE.org>

Input file. Required.

=item B<-o FILE.html>

Output file. Default, if not specfied the extension will be removed
from the input file and ".html" will be appended.

=item B<-s N>

For N = 1 to 3, a hr tag will be put before heading levels N or lower.
Default: 0

=item B<-h>

Output this "long" usage help. See "-H long"

=item B<-H pStyle>

pStyle is used to select the type of help and how it is formatted.

Styles:

    short|usage - Output short usage help as text.
    long|text   - Output long usage help as text.
    man         - Output long usage help as a man page.
    html        - Output long usage help as html.
    md          - Output long usage help as markdown.

=back

=for comment =head2 Globals
=for comment =head1 RETURN VALUE
=for comment =head1 ERRORS
=head1 EXAMPLES

If no options, file order matters.

    org2html test.org test.html

Use the -i and -o options

    org2html -o test.html -i test.org

Output file will default to test.html

    org2html -i test.org

=head1 ENVIRONMENT

    Tmp - if not set, set it to: /tmp/$USER/org2html.sh"}
    gpDebug - if set not equal to 0, all files in $Tmp will be removed

=for comment =head1 FILES

=head1 SEE ALSO

    pandoc
    perl
    pod2html - perl pkg
    pod2man - perl pkg
    pod2markdown - libpod-markdown-perl pkg
    pod2pdf
    pod2text - perl pkg
    pod2usage - perl pkg
    sed
    tidy

=for comment =head1 NOTES
=for comment =head1 CAVEATS
=for comment =head1 DIAGNOSTICS
=for comment =head1 BUGS
=for comment =head1 RESTRICTIONS
=for comment =head1 AUTHOR

=head1 HISTORY

GPLv2 (c) Copyright

=cut
EOF
    exit 1
} # fUsage


# ========================================
# Main

cBin=${0%/*}
if [[ "$cBin" = "." ]]; then
    cBin=$PWD
fi
cd $cBin >/dev/null 2>&1
cBin=$PWD
cd - >/dev/null 2>&1

# -------------------
# Setup Tmp files
if [[ ! -d $Tmp ]]; then
    mkdir -p $Tmp
fi
if [[ $gpDebug -eq 0 ]]; then
    rm $Tmp/* 2>/dev/null
fi

export cPID=$$
export cTmpF=$Tmp/file-$cPID
cTmp1=${cTmpF}-part1.tmp
cTmp2=${cTmpF}-part2.tmp
cTmp3=${cTmpF}-part3.tmp
cTmp4=${cTmpF}-part4.tmp
cTmpErr=${cTmpF}-part3.err
cPreFix=${cTmpF}-prefix.sed
cPreFixPl=${cTmpF}-prefix.pl
cPostFix=${cTmpF}-postfix.sed

# -------------------
# Get Args Section
if [ $# -eq 0 ]; then
    fUsage short
fi

while getopts :i:o:s::hH: tArg; do
    case $tArg in
        # Script arguments
        i) gpFileIn="$OPTARG" ;;
        o) gpFileOut="$OPTARG" ;;
        s) gpSep="$OPTARG" ;;
        # Common arguments
        h)
            fUsage long
            exit 1
            ;;
        H)
            fUsage $OPTARG
            ;;
        # Problem arguments
        :) echo "Error: Value required for option: -$OPTARG"
           fUsage usage
           exit 1
        ;;
        \?) echo "Error: Unknown option: $OPTARG"
            fUsage usage
            exit 1
        ;;
    esac
done
((--OPTIND))
shift $OPTIND
if [ $# -eq 1 ]; then
    gpFileIn=$1
fi
if [ $# -eq 2 ]; then
    gpFileIn=$1
    gpFileOut=$2
fi
while [ $# -ne 0 ]; do
    shift
done

if [[ -z "$gpFileIn" ]]; then
    echo "Error: Missing input file."
    fUsage usage
    exit 1
fi

if [[ ! -r $gpFileIn ]]; then
    echo "Error: cannot read file: $gpFileIn"
    fUsage usage
    exit 1
fi

if [[ -z "$gpFileOut" ]]; then
    gpFileOut=${gpFileIn%.*}.html
    echo "Notice: Output to: $gpFileOut"
fi

# -------------------
# Helper files

cat <<\EOF >$cPreFix
s/^ *- /\n\n/g
s;^\*\*\*\* \(.*\);\n<h4>\1</h4>\n;
s;^\*\*\*\*\* \(.*\);\n<h5>\1</h5>\n;
s;^\*\*\*\*\*\* \(.*\);\n<h6>\1</h6>\n;
EOF

cat <<\EOF >$cPreFixPl
    while (<>) {
        s/\[TBD([^]]*])/<span class="tbd">[TBD$1<\/span>/;
        s/\[TK([^]]*])/<span class="tbd">[TK$1<\/span>/;
        print $_;
    }
EOF

cat <<\EOF >$cPostFix
s/\&lt;/\</g
s/\&gt;/>/g

s/<p><p/<p/g
s;</p></p>;</p>;g

s/<p>\(<blockquote[^>]*>\)/\1<p>/
s;</blockquote></p>;</p></blockquote>;

s/\&quot;/"/g
s;<p></p>;;g
s;<p><div ;<div ;g
s;</div></p>;</div>;g

s|<p>&lt;h4&gt;|<h4>|g
s|&lt;/h4&gt;</p>|</h4>|g

s|<p>&lt;h5&gt;|<h5>|g
s|&lt;/h5&gt;</p>|</h5>|g

s|<p>&lt;h6&gt;|<h6>|g
s|&lt;/h6&gt;</p>|</h6>|g

s;<p><h4>;<h4>;g
s;</h4></p>;</h4>;g

s;<p><h5>;<h5>;g
s;</h5></p>;</h5>;g

s;<p><h6>;<h6>;g
s;</h6></p>;</h6>;g

s;{\(.\);<cite>{\1;g
s;\(.\)};\1}</cite>;g

s;<cite><cite>;<cite>;g
s;</cite></cite>;</cite>;g
EOF

if [[ $gpSep -ge 3 ]]; then
    echo 's;<h3;<hr><h3;g' >>$cPostFix
fi
if [[ $gpSep -ge 2 ]]; then
    echo 's;<h2;<hr><h2;g' >>$cPostFix
fi
if [[ $gpSep -ge 1 ]]; then
    echo 's;<h1;<hr><h1;g' >>$cPostFix
fi

# --------------------
# Functional section

sed -f $cPreFix  <$gpFileIn | perl  $cPreFixPl >$cTmp1
pandoc -f org -t html <$cTmp1 >$cTmp2

sed -f /$cPostFix <$cTmp2 >$cTmp3
$cTidyHtml <$cTmp3 >$gpFileOut 2>$cTmpErr

sed -i 's|/\*<!\[CDATA\[\*/|| ; s|/\*]]>\*/||' $gpFileOut

cat $cTmpErr
echo
echo "If lots of errors, see: $cTmp3 and $cTmpErr"
