"""
Main application front-end
"""
import os
import shutil

from pytemplate.incremental_formatter import IncrementalFormatter


def produce_file(template_file, target_file, **kwargs):
    """ Uses an `IncrementalFormatter` to specialize a template file.
    """
    formatter = IncrementalFormatter()
    with open(template_file) as template:
        with open(target_file, "w") as target:
            target.write(formatter.format(template.read(), **kwargs))


def get_input():
    """ Queries the user for input.
    """
    return {
        "project": input("Project Name: "),
        "description": input("Description: "),
        "name": input("Your Name: "),
        "email": input("Email: "),
        "url": input("Url: "),
        "test_runner": input("Test Runner (nose, nose2, unittest, etc): "),
        "test_runner_options": input("Test Runner Options: "),
    }


def seed_project(project_directory):
    """ Entry point for a full run of pytemplate.
    """
    kwargs = get_input()
    template_directory = os.path.join(os.path.dirname(__file__), "..", "data", "project_template")
    templates = os.listdir(template_directory)
    if not os.path.exists(project_directory):
        os.mkdir(project_directory)
    for template_filename in templates:
        print(template_filename)
        target_filename = template_filename[:-9]
        produce_file(os.path.join(template_directory, template_filename),
                     os.path.join(project_directory, target_filename),
                     **kwargs)


if __name__ == '__main__':
    if os.path.exists("test_project"):
        shutil.rmtree("test_project")
    seed_project("test_project")
