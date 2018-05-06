from setuptools import setup

setup(
    name='PyTemplate',
    version='0.1',
    description='A Python Packaging template application.',
    author='Tom Manner',
    author_email='tom.s.manner@gmail.com',
    url='https://www.github.com/tsmanner/pytemplate',
    # Packages to install
    packages=[
        'pytemplate',
    ],
    # Executables to install
    scripts=[
        "bin/pytemplate",
    ],
    package_data={
        "project_template": "project_template/*"
    },
    # Libraries required by install
    install_requires=[
        "pyaml"
    ],
)
