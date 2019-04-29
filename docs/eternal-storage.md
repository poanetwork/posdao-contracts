---
title: Eternal Storage
---

<div class="contracts">

## Contracts

### `EternalStorage`

This contract holds all the necessary state variables to carry out the storage of any upgradable contract
 and to support the upgrade functionality.

<div class="contract-index"></div>





### `EternalStorageProxy`

This proxy holds the storage of an upgradable contract and delegates every call to the current implementation.
 It allows the contract&#x27;s behavior to be updated and provides authorization control functionality.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#EternalStorageProxy.constructor(address,address)"><code class="function-signature">constructor(address _implementationAddress, address _ownerAddress)</code></a></li><li><a href="#EternalStorageProxy.fallback()"><code class="function-signature">fallback()</code></a></li><li><a href="#EternalStorageProxy.transferOwnership(address)"><code class="function-signature">transferOwnership(address _newOwner)</code></a></li><li><a href="#EternalStorageProxy.upgradeTo(address)"><code class="function-signature">upgradeTo(address _newImplementation)</code></a></li><li><a href="#EternalStorageProxy.getOwner()"><code class="function-signature">getOwner()</code></a></li><li><a href="#EternalStorageProxy.implementation()"><code class="function-signature">implementation()</code></a></li><li><a href="#EternalStorageProxy.version()"><code class="function-signature">version()</code></a></li><li><a href="#EternalStorageProxy._isContract(address)"><code class="function-signature">_isContract(address _addr)</code></a></li><li><a href="#EternalStorageProxy._setImplementation(address)"><code class="function-signature">_setImplementation(address _implementationAddress)</code></a></li><li><a href="#EternalStorageProxy._setVersion(uint256)"><code class="function-signature">_setVersion(uint256 _newVersion)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#EternalStorageProxy.OwnershipTransferred(address,address)"><code class="function-signature">OwnershipTransferred(address previousOwner, address newOwner)</code></a></li><li class="inherited"><a href="#EternalStorageProxy.Upgraded(uint256,address)"><code class="function-signature">Upgraded(uint256 version, address implementation)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.constructor(address,address)"></a><code class="function-signature">constructor(address _implementationAddress, address _ownerAddress)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.fallback()"></a><code class="function-signature">fallback()</code></h4>

Fallback function allowing a `delegatecall` to the given implementation.
 This function will return whatever the implementation call returns.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.transferOwnership(address)"></a><code class="function-signature">transferOwnership(address _newOwner)</code></h4>

Allows the current owner to irrevocably transfer control of the contract to a `_newOwner`.
 @param _newOwner The address ownership is transferred to.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.upgradeTo(address)"></a><code class="function-signature">upgradeTo(address _newImplementation) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Allows the owner to upgrade the current implementation.
 @param _newImplementation Represents the address where the new implementation is set.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.getOwner()"></a><code class="function-signature">getOwner() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the address of the contract owner.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.implementation()"></a><code class="function-signature">implementation() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the address of the current implementation.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.version()"></a><code class="function-signature">version() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the version number of the current implementation.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy._isContract(address)"></a><code class="function-signature">_isContract(address _addr) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Checks whether the specified address is a contract address.
 Returns `false` if the address is an EOA (externally owned account).
 @param _addr The address which needs to be checked.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy._setImplementation(address)"></a><code class="function-signature">_setImplementation(address _implementationAddress)</code></h4>

Sets the implementation address.
 @param _implementationAddress The address of implementation.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy._setVersion(uint256)"></a><code class="function-signature">_setVersion(uint256 _newVersion)</code></h4>

Sets the version number.
 @param _newVersion The version number.





<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.OwnershipTransferred(address,address)"></a><code class="function-signature">OwnershipTransferred(address previousOwner, address newOwner)</code></h4>

Emitted by the `transferOwnership` function every time the ownership of this contract changes.
 @param previousOwner Represents the previous owner of the contract.
 @param newOwner Represents the new owner of the contract.



<h4><a class="anchor" aria-hidden="true" id="EternalStorageProxy.Upgraded(uint256,address)"></a><code class="function-signature">Upgraded(uint256 version, address implementation)</code></h4>

Emitted by the `upgradeTo` function every time the implementation gets upgraded.
 @param version The new version number of the upgraded implementation.
 @param implementation The new address of the upgraded implementation.



### `OwnedEternalStorage`

Provides access control functionality and extends the `EternalStorage` contract.
 Using the `onlyOwner` modifier, a function can be restricted so that it can only be 
 called by the owner of the contract. The owner of a contract can irrevocably transfer 
 ownership using the `EternalStorageProxy.transferOwnership` function.

<div class="contract-index"></div>





</div>