"""Pack the generated Dendro medallions into the mod's existing KTEX format."""
from element_medallions import pack_medallions


if __name__ == "__main__":
    pack_medallions("dendro", ("passive", "root", "field"))
