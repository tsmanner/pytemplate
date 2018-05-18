import string


class IterativeFormatter(string.Formatter):
    """ Formatter class that will partially format a string.
        To do this, it only operates on keyword arguments.
    """
    def format(self, format_string, **kwargs):
        """ Add missing fields to kwargs with a format value of {field}.
        """
        fmt = self.parse(format_string)
        for literal_text, field_name, format_spec, conversion in fmt:
            if field_name and field_name not in kwargs:
                kwargs[field_name] = "{" + field_name + "}"
        return super().format(format_string, **kwargs)
