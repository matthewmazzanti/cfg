from __future__ import annotations
import requests
import json
from dataclasses import dataclass
from pathlib import Path
import sys

@dataclass
class DockerImage:
    unparsed: str
    reg: str
    auth: str
    repo: str
    image: str
    tag: str


    @classmethod
    def parse(cls, raw_image: str) -> DockerImage:
        image_ref, tag = tuple(raw_image.split(":"))

        image_data = image_ref.split("/")

        # Image will always be the last item
        image = image_data.pop()

        # May have a repo name, but otherwise defaults to "library"
        if len(image_data):
            repo = image_data.pop()
        else:
            repo = "library"

        # May have a registry name. Use defaults for docker
        if len(image_data):
            reg = image_data.pop()
            auth = reg
        else:
            reg = "registry-1.docker.io"
            auth = "auth.docker.io"

        return DockerImage(
            unparsed=raw_image,
            reg=reg,
            auth=auth,
            repo=repo,
            image=image,
            tag=tag
        )

def get_token(image: DockerImage):
    res = requests.get(
        f"https://{image.auth}/token",
        params={
            "service": "registry.docker.io",
            "scope": f"repository:{image.repo}/{image.image}:pull",
        }
    )

    return res.json()["token"]


def get_manifests(image: DockerImage, token: str):
    res = requests.get(
        f"https://{image.reg}/v2/{image.repo}/{image.image}/manifests/{image.tag}",
        headers={
            "Accept": "application/vnd.docker.distribution.manifest.v2+json",
            "Authorization": f"Bearer {token}",
        },
    )
    return res.json()["manifests"]

def lock_image(image_name: str) -> tuple[DockerImage, str]:
    image = DockerImage.parse(image_name)

    token = get_token(image)

    manifests = get_manifests(image, token)

    for manifest in manifests:
        platform = manifest["platform"]
        if platform["architecture"] == ARCH and platform["os"] == OS:
            return image, manifest["digest"]

    raise ValueError()


# If I change platforms, I'll have to make this configurable
ARCH = "amd64"
OS = "linux"

def main():
    input_path = Path(sys.argv[1])
    output_path = input_path.parent.joinpath("images.lock")
    print(f"locking {input_path} to {output_path}")

    with open(input_path) as f:
        input = json.load(f)

    output = {}
    for name, image_ref in input.items():
        image, sha = lock_image(image_ref)
        output[name] = {
            "lock": f"{image.reg}/{image.repo}/{image.image}@{sha}",
            "image": image_ref,
            "platform": {
                "architecture": ARCH,
                "os": OS,
            },
        }

    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
