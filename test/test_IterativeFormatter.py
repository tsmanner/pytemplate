"""
Unit Tests for the `IterativeFormatter` class
"""
import unittest

from pytemplate.iterative_formatter import IterativeFormatter


# noinspection PyUnreachableCode
class TestIterativeFormatter(unittest.TestCase):
    def setUp(self):
        self.formatter = IterativeFormatter()

    def tearDown(self):
        del self.formatter

    def test_format(self):
        with self.subTest("No Format Specifiers"):
            test_string = "hello world."
            self.assertEqual(test_string, self.formatter.format(test_string))
        with self.subTest("No Missing Fields"):
            test_string = "hello {something}."
            expected_result = "hello world."
            kwargs = {
                "something": "world",
            }
            self.assertEqual(expected_result, self.formatter.format(test_string, **kwargs))
        with self.subTest("Missing Fields"):
            test_string = "{greeting} {something}."
            expected_result = "hello {something}."
            kwargs = {
                "greeting": "hello",
            }
            self.assertEqual(expected_result, self.formatter.format(test_string, **kwargs))
        with self.subTest("Iterative Formatting"):
            test_string = "{greeting} {something}."
            expected_result = "hello world."
            inc_kwargs = {
                "greeting": "hello",
            }
            kwargs = {
                "something": "world",
            }
            inc_string = self.formatter.format(test_string, **inc_kwargs)
            self.assertEqual(expected_result, self.formatter.format(inc_string, **kwargs))
        with self.subTest("Extra Fields"):
            test_string = "hello {something}."
            expected_result = "hello world."
            kwargs = {
                "something": "world",
                "else": "rawr",
            }
            self.assertEqual(expected_result, self.formatter.format(test_string, **kwargs))
        with self.subTest("With Positional Arguments"):
            self.assertRaises(TypeError)
