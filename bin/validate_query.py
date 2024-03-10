import argparse
import json
import pandas as pd
import numpy as np
import plotly.express as px
import requests

def main():
    parser = argparse.ArgumentParser(description="query validation")
    parser.add_argument('query', help='query')
    parser.add_argument('output_validation', help='output_validation')

    args = parser.parse_args()

    url = "https://massql.gnps2.org/parse?query={}".format(args.query)

    r = requests.get(url)

    r.raise_for_status()

    with open(args.output_validation, 'w') as f:
        f.write(r.text)



if __name__ == "__main__":
    main()
