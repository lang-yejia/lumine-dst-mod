"""Pack the Pyro sprite sheet into skill, element, and essence atlases."""

from element_medallions import pack_medallions


if __name__ == "__main__":
    pack_medallions("pyro", ("passive", "ring", "burst", "orb"), columns=3)
