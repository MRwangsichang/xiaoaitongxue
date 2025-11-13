import argparse
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--smoke", action="store_true")
    args = ap.parse_args()
    if args.smoke:
        print("SMOKE OK")
if __name__ == "__main__":
    main()
