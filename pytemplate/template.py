"""
Main application front-end
"""

import argparse
import sys


def produce_file(template, target, **kwargs):



def parse_args(argv):
    """ Handle the command line arguments.
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("project", required=False, default=None, help="Your project's name")
    return ap.parse_args(argv[1:])


def main(argv=sys.argv):
    """ Entry point for a full run of pytemplate.
    """
    args = parse_args(argv)
    if args.project is None:
        args.project = input("Project Name: ")
