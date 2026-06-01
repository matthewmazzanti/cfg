import json
import hashlib

def qwer():
    return

def identity(x):
    return x

# This is some long
# and complex
# comment
# Just making
# sure that it
# still works
def foobar(qwer, world):
    """
    qwer              
    """
    print(qwer, world)
    print()
    "a line with multiple is"

def barbaz():
    foobar("hello", "world")
    for i in range(0, 10):
        print(i)

def partial_test():
    foobar(barbaz(), "world")

def example():
    hashlib.sha256()

def hash_json(obj):
    """
    Compute a deterministic hash for a JSON-serializable Python object.
    The function ensures that the hash is the same for semantically equivalent objects,
    regardless of key order in dictionaries.

    Args:
        obj: A JSON-serializable Python object.

    Returns:
        str: A hexadecimal SHA256 hash of the canonical JSON representation.
    """
    # Use sort_keys=True to ensure deterministic output for dicts
    canonical_json = json.dumps(obj, sort_keys=True, separators=(',', ':'))
    return hashlib.sha256(canonical_json.encode('utf-8')).hexdigest()

def hash_json_acc(obj, acc=0):
    """
    Recursively computes a hash for a JSON-like object, updating the hash incrementally.
    Supports dict, list, tuple, str, int, float, bool, and None.
    """
    match obj:
        case dict():
            for key in sorted(obj.keys()):
                acc = hash_json_acc(key, acc)
                acc = hash_json_acc(obj[key], acc)
            acc = hash((acc, 'dict'))
        case list() | tuple():
            for item in obj:
                acc = hash_json_acc(item, acc)
            acc = hash((acc, 'list' if isinstance(obj, list) else 'tuple'))
        case str() | int() | float() | bool() | None:
            acc = hash((acc, hash(obj)))
        case _:
            raise TypeError(f"Unsupported type: {type(obj)}")
    return acc

