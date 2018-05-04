#!/usr/bin/env python3
"""
Setup script for `bajada`.
"""

from setuptools import setup

setup(
    name="Bajada", 
    version="0.1", 
    description="A Python3 constrained digraph based process runner",
    author="Tom Manner",
    author_email="tsmanner@us.ibm.com",
    url="https://github.ibm.com/EDA/bajada",
    packages=[
        "bajada"
    ],
    scripts=[
        "bin/bajada",
        "bin/bajada.bat",
    ],
    python_requires=">=3.6",
)
