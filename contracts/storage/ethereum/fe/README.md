# Storage

This contract should allow to store on-chain two types of data - bytes and strings.

## Initialization

This contract has no `__init__` function.

## Technical challenges

This use case requires the SC language to have *Dynamic arrays*. Fe is currently designed to have static arrays.

### Strings are not dynamic, as Fe's documentation says:

*A value of type String `<N>` represents a sequence of unsigned bytes with the assumption that the data is valid UTF-8.*
*The String `<N>` type is generic over a constant value that has to be an integer literal. That value N constraints the maximum number of bytes that are available for storing the string's characters.*
*Note that the value of N does not restrict the type to hold exactly that number of bytes at all times which means that a type such as String<10> can hold a short word such as "fox" but it can not hold a full sentence such as "The brown fox jumps over the white fence".*

### Arrays are not dynamic, as Fe's documentation says:

*"An array is a fixed-size sequence of N elements of type T. The array type is written as Array<T, N>. The size is an integer literal.*
*Arrays are either stored in storage or memory but are never stored directly on the stack."*

### Only sequence types can be stored in memory. Citing Fe documentation:

*The first memory slot (0x00) is used to keep track of the lowest available memory slot. Newly allocated segments begin at the value given by this slot. When more memory has been allocated, the value stored in 0x00 is increased.*

**Also, Fe has no garbage collection:**

*We do not free memory after it is allocated.*

**The most reasonable workaround in a situation where dynamic arrays are unavailable is to make the arrays big enough in advance, with the risk of wasting memory.**

## Execution

After the contract is deployed, 2 functions can be called.

### storeBytes(_byteSequence: Array<u8, 1>)

This function allows to store bytes up to one *uint8* byte in memory. Since Fe does not support dynamic arrays, when trying to give a byte bigger than 255, it returns `custom error` which is probably a Fe temporary error because the language is still in development.

### storeString(_textString: String<10>)

This function allows to store strings up to 10 chars in memory. Since Fe does not support dynamic arrays, and strings are saved as arrays, when trying to give a string longer than 10 chars, it returns `custom error` which is probably a Fe temporary error because the language is still in development.