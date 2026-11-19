"""Pack Cryo medallions into skill, element, and essence atlases."""

from element_medallions import pack_medallions


if __name__ == "__main__":
    pack_medallions("cryo", ("passive", "infusion", "meteor"))
