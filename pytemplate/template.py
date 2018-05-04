"""
"""

import argparse


def parse_args(argv):
    """
    Handle the command line arguments.
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("config_file", help="The json config file to load.")
    ap.add_argument("flow", default=None, nargs="?", help="The flow from config_file to run.")
    ap.add_argument("--quiet", "-q", default=False, action="store_true", help="Disables shell progress prints.")
    ap.add_argument("--verbose", "-v", default=False, action="store_true", help="Dump all process output to 'bajada.log'.")
    ap.add_argument("--log", nargs=1, action="store", choices={"critical", "error", "warn", "warning", "info", "debug"}, help="Set the bajada debug logging level.")
    return ap.parse_args(argv[1:])


def main(argv=sys.argv):
    args = parse_args(argv)

    # Set up the loggers.
    logfile_formatter = logging.Formatter("%(asctime)s [%(name)s]  %(message)s")
    bajada_log_handler = logging.FileHandler("bajada.log")
    bajada_log_handler.setFormatter(logfile_formatter)
    terminal_handler = logging.StreamHandler(sys.stdout)

    if args.log:
        logging.getLogger("bajada").addHandler(bajada_log_handler)
        logging.getLogger("bajada").setLevel(eval(f"logging.{args.log[0].upper()}"))

    if args.flow is not None:
        flow_log_handler = logging.FileHandler(f"{args.flow}.log")
        flow_log_handler.setFormatter(logfile_formatter)
        logger_name = f"progress.{args.flow}"
        logging.getLogger(logger_name).setLevel(logging.INFO)
        if not args.quiet:
            logging.getLogger(logger_name).addHandler(shell_handler)
        if args.verbose:
            logging.getLogger("").setLevel(logging.INFO)
            logging.getLogger("").addHandler(flow_log_handler)
        else:
            logging.getLogger(logger_name).addHandler(flow_log_handler)


    if not os.path.isfile(args.config_file):
        print(f"file not found: '{args.config_file}'")
    else:
        config = ConfigFile(args.config_file)
        if args.flow == None:
            print(f"Available flows in '{args.config_file}':")
            [print(f"    {fn}") for fn in config]
        elif args.flow not in config:
            print(f"workflow '{args.flow}' not found in '{args.config_file}'")
        else:
            config.run(args.flow)
