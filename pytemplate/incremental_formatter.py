"""
Defines a string Formatter that allows incremental specialization.
For example:
    s = "{x} {y}"
    s = IncrementalFormatter().format(s, x="hello")
    print(s)  # "hello {y}"
    s = IncrementalFormatter

"""
import string


class IncrementalFormatter(string.Formatter):
    """ Formatter class that will partially format a string.
        To do this, it only operates on keyword arguments.
    """
    def format(self, format_string, **kwargs):
        """ Add missing fields to kwargs with a format value of {field}.
        """
        fmt = self.parse(format_string)
        for _, field_name, _, _ in fmt:
            if field_name and field_name not in kwargs:
                kwargs[field_name] = "{" + field_name + "}"
        return super().format(format_string, **kwargs)
