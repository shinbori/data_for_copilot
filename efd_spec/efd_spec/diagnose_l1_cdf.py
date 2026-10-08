#!/usr/bin/env python3
"""Diagnose CDF readability and variable record metadata for L1 label generation."""
from __future__ import annotations
import argparse
import traceback
from pathlib import Path


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('cdf', type=Path)
    args=ap.parse_args()
    path=args.cdf.expanduser().resolve()
    print(f'CDF: {path}')
    print(f'Size: {path.stat().st_size} bytes')
    try:
        from cdflib import CDF
        cdf=CDF(str(path))
        info=cdf.cdf_info()
        z=list(getattr(info,'zVariables',[]) or [])
        r=list(getattr(info,'rVariables',[]) or [])
        print(f'zVariables: {len(z)}')
        print(f'rVariables: {len(r)}')
        failures=0
        for name in r+z:
            try:
                vi=cdf.varinq(name)
                data=cdf.varget(name)
                shape=getattr(data,'shape',None)
                size=getattr(data,'size',None)
                print(f'OK {name}: last_rec={getattr(vi,"Last_Rec",None)} rec_vary={getattr(vi,"Rec_Vary",None)} shape={shape} size={size}')
            except Exception as exc:
                failures+=1
                print(f'FAIL {name}: {type(exc).__name__}: {exc}')
                traceback.print_exc()
        if failures:
            raise SystemExit(1)
        print('All variables are readable through cdflib.varget().')
    except Exception:
        traceback.print_exc()
        raise

if __name__=='__main__': main()
