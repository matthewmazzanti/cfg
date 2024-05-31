from setuptools import setup

setup(
    name="kitty_si",
    version="0.0.1",
    py_modules=["kitty_si"],
    entry_points={"console_scripts": ["kitty-si=kitty_si:main"]},
)
