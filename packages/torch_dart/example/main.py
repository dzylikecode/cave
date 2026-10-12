import torch

x = torch.zeros(2, 3, device="cuda:0")
print(x.device)

x.requires_grad 
