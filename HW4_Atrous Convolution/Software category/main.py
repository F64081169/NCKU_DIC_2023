import numpy as np
from PIL import Image
import torchvision.transforms as transforms
import torch
import os

if os.path.exists('./image.png'):
    image = Image.open('./image.png')
else:
    image = Image.open('./image.jpg')

# pre-processing : gray scale & resize
image_gray = image.convert('L')
resize_transform = transforms.Resize((64, 64), interpolation=transforms.InterpolationMode.BILINEAR, antialias=True)
image_resize = np.array(resize_transform(image_gray))

# Layer 0 : Padding (64x64 -> 68x68) & atrous convolution dilation = 2, stride = 1 & ReLU
image_pad = np.pad(image_resize, ((2, 2), (2, 2)), 'edge')
# atrous convolution dilation = 2, stride = 1 
kernel = np.array([[-0.0625, 0, -0.125, 0, -0.0625],
                   [0,       0,  0,     0,  0     ],
                   [-0.25,   0,  1,     0, -0.25  ],
                   [0,       0,  0,     0,  0     ],
                   [-0.0625, 0, -0.125, 0, -0.0625]])
bias = -0.75

image_pad_tensor = torch.from_numpy(image_pad).unsqueeze(0).unsqueeze(0).float() 
kernel_tensor = torch.from_numpy(kernel).unsqueeze(0).unsqueeze(0).float()  
bias_tensor = torch.tensor([bias])
output_tensor = torch.nn.functional.conv2d(image_pad_tensor, kernel_tensor, bias=bias_tensor)  
output_numpy = output_tensor.numpy().astype(np.float64)
# ReLU : if x > 0, x else 0
output_numpy[output_numpy < 0] = 0

# Layer 1 : Max-pooling the output of Layer 0 (stride=2, kernel_size=2x2) 
# Round up the result of Max-pooling to the nearest integer
layer1 = np.zeros((output_numpy.shape[0], output_numpy.shape[1], output_numpy.shape[2] // 2, output_numpy.shape[3] // 2))
for i in range(layer1.shape[2]):
    for j in range(layer1.shape[3]):
        layer1[:,:,i,j] = np.max(output_numpy[:,:,i*2:i*2+2,j*2:j*2+2], axis=(2,3))

layer1 = np.ceil(layer1)

# img.dat
with open('img.dat', 'w') as f:
    for i in range(64):
        for j in range(64):
            binary_str = '{0:013b}'.format(image_resize[i][j] * 16)
            f.write(binary_str + ' //data ' + str(i * image_resize.shape[0] + j) + ': ' + '{0:.1f}'.format(image_resize[i][j]) + '\n')

# layer0_golden.dat
with open('layer0_golden.dat', 'w') as f:
    for i in range(64):
        for j in range(64):
            binary_str = '{0:09b}'.format(int(output_numpy[0][0][i][j]))
            binary_str2 = '{0:04b}'.format(int((output_numpy[0][0][i][j] % 1) * 16))
            if output_numpy[0][0][i][j] % 1 == 0:
                data_str = '{:.1f}'.format(output_numpy[0][0][i][j])
            else:
                data_str = '{:.6g}'.format(output_numpy[0][0][i][j])
            f.write(binary_str + binary_str2 +  ' //data ' + str(i * 64 + j) + ': ' + data_str + '\n')

# layer1_golden.dat
with open('layer1_golden.dat', 'w') as f:
    for i in range(32):
        for j in range(32):
            binary_str = '{0:09b}'.format(int(layer1[0][0][i][j]))
            binary_str2 = '{0:04b}'.format(int((layer1[0][0][i][j] % 1) * 16))
            if layer1[0][0][i][j] % 1 == 0:
                data_str = '{:.1f}'.format(layer1[0][0][i][j])
            else:
                data_str = '{:.6g}'.format(layer1[0][0][i][j])
            f.write(binary_str + binary_str2 + ' //data ' + str(i * 32 + j) + ': ' + data_str + '\n')
