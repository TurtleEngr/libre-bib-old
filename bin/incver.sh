#!/usr/bin/env bash
set -u
export cName=incver.sh

# ========================================
# Functions

# --------------------
fUsage() {
    local pStyle="${1:-usage}"
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

=head1 NAME incver.sh

Increment version number in a version file

=head1 SYNOPSIS

    inver.sh [-M -m -p] [-s pChar] [-h] [-H pStyle] [-f FILE]

=head1 DESCRIPTION

Increment version number in FILE. Format in FILE: Major.Minor.Patch
First initialize the version of FILE to have 3 numbers, e.g. 1.0.0

=head1 OPTIONS

=over 4

=item B<-M>

Increment the major number (first).

=item B<-m>

Increment the minor number (second).

=item B<-p>

Increment the patch number (third).

=item B<-s pChar>

Change the separator charactre. Default: '.'

=item B<-f FILE or FILE>

If missing the default is: VERSION

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
=for comment =head1 EXAMPLES
=for comment =head1 ENVIRONMENT
=for comment =head1 FILES
=for comment =head1 SEE ALSO
=for comment =head1 NOTES
=for comment =head1 CAVEATS
=for comment =head1 DIAGNOSTICS
=for comment =head1 BUGS
=for comment =head1 RESTRICTIONS
=for comment =head1 AUTHOR

=head1 HISTORY

GPLv2 (c) Copyright

$Revision: 1.5 $ $Date: 2025/06/01 01:12:24 $ GMT

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
# Get Args Section

if [ $# -eq 0 ]; then
    fUsage usage
fi

gpLevel=""
gpFile="VERSION"
gpSep='.'

while getopts :Mmps:f:hH: tArg; do
    case $tArg in
        # Script arguments
        M) gpLevel="M" ;;
        m) gpLevel="m" ;;
        p) gpLevel="p" ;;
        s) gpSep="$OPTARG" ;;
        f) gpFile="$OPTARG" ;;
        # Common arguments
        h)
            fUsage long
            exit 1
            ;;
        H)
            fUsage $OPTARG
            ;;
        # Problem arguments
        :)
            echo "Error: Value required for option: -$OPTARG"
            fUsage usage
            exit 1
            ;;
        \?)
            echo "Error: Unknown option: $OPTARG"
            fUsage usage
            exit 1
            ;;
    esac
done
((--OPTIND))
shift $OPTIND
gpList=""
if [ $# -ne 0 ]; then
    gpList="$*"
fi
while [ $# -ne 0 ]; do
    shift
done

if [ -z "$gpLevel" ]; then
    echo "Error: one of -M, -m, or -p is required."
    fUsage usage
fi

if [ -z "$gpFile" ]; then
    gpFile="VERSION"
    if [ -n "$gpList" ]; then
        gpFile=${gpList%% *}
    fi
fi

if [ ! -w $gpFile ]; then
    echo "Error: $gpFile is missing or is not writable."
    fUsage usage
fi

# --------------------
# Functional section

IFS=$gpSep
read tMajor tMinor tPatch tExtra < <(cat "$gpFile")
IFS=' '
if [ -n "$tExtra" ]; then
    tExtra="$gpSep$tExtra"
fi

case $gpLevel in
    M)
        ((++tMajor))
        tMinor=0
        tPatch=0
        ;;
    m)
        ((++tMinor))
        tPatch=0
        ;;
    p)
        ((++tPatch))
        ;;
esac

echo "${tMajor}${gpSep}${tMinor}${gpSep}${tPatch}$tExtra" >$gpFile

exit 0
