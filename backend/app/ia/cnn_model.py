# backend/app/ia/cnn_model.py

import torch
import torch.nn as nn


class BasicBlock3D(nn.Module):
    expansion = 1

    def __init__(self, in_planes: int, planes: int, stride: int = 1):
        super().__init__()

        self.in_planes = in_planes
        self.planes = planes
        self.stride = stride

        self.conv1 = nn.Conv3d(
            in_planes,
            planes,
            kernel_size=3,
            stride=stride,
            padding=1,
            bias=False,
        )
        self.bn1 = nn.BatchNorm3d(planes)

        self.conv2 = nn.Conv3d(
            planes,
            planes,
            kernel_size=3,
            stride=1,
            padding=1,
            bias=False,
        )
        self.bn2 = nn.BatchNorm3d(planes)

        self.relu = nn.ReLU(inplace=True)

    def _shortcut(self, x: torch.Tensor) -> torch.Tensor:
        """
        Shortcut sans paramètres entraînables.

        Le checkpoint fourni ne contient pas de poids downsample.
        On évite donc Conv3d + BatchNorm dans le raccourci.
        """

        out = x

        if self.stride != 1:
            out = nn.AvgPool3d(
                kernel_size=1,
                stride=self.stride,
            )(out)

        if self.planes != self.in_planes:
            channel_diff = self.planes - self.in_planes

            if channel_diff > 0:
                padding = torch.zeros(
                    out.size(0),
                    channel_diff,
                    out.size(2),
                    out.size(3),
                    out.size(4),
                    device=out.device,
                    dtype=out.dtype,
                )
                out = torch.cat([out, padding], dim=1)

        return out

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        identity = self._shortcut(x)

        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)

        out = self.conv2(out)
        out = self.bn2(out)

        out = out + identity
        out = self.relu(out)

        return out


class ResNet3D(nn.Module):
    def __init__(self, block, layers: list[int]):
        super().__init__()

        self.in_planes = 64

        self.conv1 = nn.Conv3d(
            1,
            64,
            kernel_size=7,
            stride=2,
            padding=3,
            bias=False,
        )
        self.bn1 = nn.BatchNorm3d(64)
        self.relu = nn.ReLU(inplace=True)

        self.maxpool = nn.MaxPool3d(
            kernel_size=3,
            stride=2,
            padding=1,
        )

        self.layer1 = self._make_layer(block, 64, layers[0], stride=1)
        self.layer2 = self._make_layer(block, 128, layers[1], stride=2)
        self.layer3 = self._make_layer(block, 256, layers[2], stride=2)
        self.layer4 = self._make_layer(block, 512, layers[3], stride=2)

        self.avgpool = nn.AdaptiveAvgPool3d((1, 1, 1))

        self.fc = nn.Sequential(
            nn.Dropout(p=0.5),
            nn.Linear(512, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(p=0.3),
            nn.Linear(128, 1),
        )

    def _make_layer(self, block, planes: int, blocks: int, stride: int) -> nn.Sequential:
        layers = [
            block(
                in_planes=self.in_planes,
                planes=planes,
                stride=stride,
            )
        ]

        self.in_planes = planes * block.expansion

        for _ in range(1, blocks):
            layers.append(
                block(
                    in_planes=self.in_planes,
                    planes=planes,
                    stride=1,
                )
            )

        return nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)

        x = self.maxpool(x)

        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)

        x = self.avgpool(x)
        x = torch.flatten(x, 1)

        x = self.fc(x)

        return x


def build_resnet34_3d() -> ResNet3D:
    """
    Architecture ResNet34 3D compatible avec le checkpoint fourni.

    layers = [3, 4, 6, 3]
    """
    return ResNet3D(
        block=BasicBlock3D,
        layers=[3, 4, 6, 3],
    )