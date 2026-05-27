import argparse
import re
import sys
import requests

# Constructs the Rust ("fast") engine does not support. See
# MassQueryLanguage_Rust/README.md "Not ported (yet)". Each entry is
# (compiled regex, human-readable explanation).
FAST_UNSUPPORTED = [
    (re.compile(r"\|\|\|"),
     "multiple queries delimited by '|||' (fast engine runs a single query)"),
    (re.compile(r"\bOTHERSCAN\b", re.IGNORECASE),
     "OTHERSCAN"),
    (re.compile(r"\bpeptide\s*\(", re.IGNORECASE),
     "peptide(...) expressions"),
    (re.compile(r"=\s*\(\s*QUERY", re.IGNORECASE),
     "nested subqueries (condition = (QUERY ...))"),
]


def check_fast_supported(query):
    """Return a list of unsupported-construct descriptions found in the query."""
    return [desc for pattern, desc in FAST_UNSUPPORTED if pattern.search(query)]


def main():
    parser = argparse.ArgumentParser(description="query validation")
    parser.add_argument('query', help='query')
    parser.add_argument('output_validation', help='output_validation')
    parser.add_argument('--engine', default='reference',
                        help="which engine will run the query: 'reference' (Python) or 'fast' (Rust)")

    args = parser.parse_args()

    # Fast engine supports a subset of MassQL. Reject unsupported
    # constructs up front with a clear message rather than letting the
    # Rust engine error per-file (which errorStrategy 'ignore' would
    # silently swallow into empty results).
    if args.engine == 'fast':
        unsupported = check_fast_supported(args.query)
        if unsupported:
            sys.stderr.write(
                "This query uses MassQL constructs not supported by the Fast (Rust) engine: "
                + "; ".join(unsupported)
                + ".\nSwitch the MassQL Engine option to 'Reference' to run this query.\n"
            )
            sys.exit(1)

    url = "https://massql.gnps2.org/parse?query={}".format(args.query)

    r = requests.get(url)

    r.raise_for_status()

    with open(args.output_validation, 'w') as f:
        f.write(r.text)



if __name__ == "__main__":
    main()
