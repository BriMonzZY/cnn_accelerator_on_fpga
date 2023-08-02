import numpy as np 
from scipy import signal
import subprocess
import os
import math
import skimage.measure
from numpy.random import seed

#Function to convert from the Fixed point precision that our hardware is using to the float values that python actually uses
def fp_to_float(s,integer_precision,fraction_precision):       #s = input binary string
    number = 0.0
    i = integer_precision - 1
    j = 0
    if(s[0] == '1'):
        s_complemented = twos_comp((s[1:]),integer_precision,fraction_precision)
    else:
        s_complemented = s[1:]
    while(j != integer_precision + fraction_precision -1):
        number += int(s_complemented[j])*(2**i)
        i -= 1
        j += 1
    if(s[0] == '1'):
        return (-1)*number
    else:
        return number

#Function to convert between the actual float values and the fixed point values in the particular 
#precision that our hardware is using
def float_to_fp(num, integer_precision, fraction_precision):   
    if(num<0):
        sign_bit = 1                            #sign bit is 1 for negative numbers in 2's complement                                                 #representation
        num = -1*num
    else:
        sign_bit = 0
    precision = '0'+ str(integer_precision) + 'b'
    integral_part = format(int(num),precision)
    fractional_part_f = num - int(num)
    fractional_part = []
    for i in range(fraction_precision):
        d = fractional_part_f*2
        fractional_part_f = d -int(d)        
        fractional_part.append(int(d))
    fraction_string = ''.join(str(e) for e in fractional_part)
    if(sign_bit == 1):
        binary = str(sign_bit) + twos_comp(integral_part + fraction_string,integer_precision,fraction_precision)
    else:
        binary = str(sign_bit) + integral_part+fraction_string
    return str(binary)


#Function to calculate 2's complement of a binary number
def twos_comp(val,integer_precision,fraction_precision):
    flipped = ''.join(str(1-int(x))for x in val)
    length = '0' + str(integer_precision+fraction_precision) + 'b'
    bin_literal = format((int(flipped,2)+1),length)
    return bin_literal


#Function to perform convolution between an input array and a filter array
def strideConv(arr, arr2, s):
    return signal.convolve2d(arr, arr2[::-1, ::-1], mode='valid')[::s, ::s]

if __name__ == '__main__':

    #setting random seed values for each call to random.uniform
    seed(17)
    #numpy array representing the input activation map
    values = np.random.uniform(-1,1,36).reshape((6,6))
    seed(2)
    #numpy array representing the kernel of weights
    weights = np.random.uniform(-1,1,9).reshape((3,3))
    #2-D Convolution operation
    conv = strideConv(values,weights,1)
    #Activation function (alternatively this can be replaced by the Tanh function)
    conv_relu = np.maximum(conv,0)
    #Pooling function (alternatively np.max can be used as the last argument for max pooling)
    pool = skimage.measure.block_reduce(conv_relu, (2,2), np.average)                                       
    #Converting all our arrays into the fixed point format of our choice to feed it to hardware

    values_fp = []
    for a in values:
        for b in a:
            values_fp.append(float_to_fp(b, 3, 12))

    values_fp_reshaped = np.reshape(values_fp,(6,6))
    print('\nvalues')
    print(values)
    print(values_fp_reshaped)

    weights_fp=[]
    for a in weights:
        for b in a:
            weights_fp.append(float_to_fp(b, 3, 12))

    weights_fp = np.reshape(weights_fp,(3,3))
    print('\nweights')
    print(weights)
    print(weights_fp)

    conv_fp=[]
    for a in conv:
        for b in a:
            conv_fp.append(float_to_fp(b, 3, 12))

    conv_fp = np.reshape(conv_fp,(4,4))
    print('\nconvolved output')
    print(conv)
    print(conv_fp)

    conv_relu_fp=[]
    for a in conv_relu:
        for b in a:
            conv_relu_fp.append(float_to_fp(b, 3, 12))

    conv_fp = np.reshape(conv_fp,(4,4))
    print('\n relu conv')
    print(conv_relu)
    print(conv_relu_fp)

    pool_fp=[]
    for x in pool:
        for y in x:
            pool_fp.append(float_to_fp(y, 3, 12))

    pool_fp = np.reshape(pool_fp,(2,2))
    print('\npooled output')
    print(pool)
    print(pool_fp)
