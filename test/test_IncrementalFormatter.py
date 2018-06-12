"""
Unit Tests for the `IncrementalFormatter` class.
"""
import unittest

from pytemplate.incremental_formatter import IncrementalFormatter


# noinspection PyUnreachableCode
class TestIncrementalFormatter(unittest.TestCase):
    """ `TestCase` for `IncrementalFormatter`.
    """

    def setUp(self):
        """ Instantiate a single IncrementalFormatter to use in the unit tests.
        """
        self.formatter = IncrementalFormatter()

    def tearDown(self):
        """ Clean up the objects we allocated at the end of the tests.
        """
        del self.formatter

    def test_format(self):
        """ Test routine for `IncrementalFormatter.format`.
        """

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


        """
        with self.subTest("With Escaped Brackets"):
            test_string = "{hello {something}.}"
            expected_result = "{hello world.}"
            kwargs = {
                "something": "world",
                "else": "rawr",
            }
            self.assertEqual(expected_result, self.formatter.format(test_string, **kwargs))
        """
