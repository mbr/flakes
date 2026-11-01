"""Tests for greeting helpers."""

from myproject import greet


def test_greet():
    """Include the supplied name in the greeting."""
    assert greet("world") == "Hello, world!"
