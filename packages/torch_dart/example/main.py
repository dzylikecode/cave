import torch
import torch.nn as nn
import torch.nn.functional as F

torch.manual_seed(66)

x = torch.zeros([1, 1, 28, 28])

class Model(nn.Module):
    def __init__(self):
        super(Model, self).__init__()
        self.conv1 = nn.Conv2d(1, 20, 5)
        self.conv2 = nn.Conv2d(20, 20, 5)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        return F.relu(self.conv2(x))

m = Model()

print(m(x))
