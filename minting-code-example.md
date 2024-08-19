# The OCTL (aspirations) in a nutshell
**Situation:**
NFTs currently only can be sold and a creator gains royalty for the trade. 


**Problem:**
For many digital artifacts, such as code or similar, many more usage scenarios than ownership transfer and associated royalty are essential.
For example, source code can be forked in different other software projects, be applied in software as a service scenarios or run on different workstations in profit or non-profit scenarios. The one using the source code does not necessarily need ownership transfer and usage license would be required instead.

Another key challenge is the usage of creative digital artifacts such as pictures or videos for AI training, compliant to EU AI acts of various economic zones.
For example to detect trains in videos one does not need to own the footage, but one would need a license for AI training and need the possibiliy to track which creative artifacts were used in the training to compensate the creators atequately. 


**Solution:**
Digital artifacts, like source code, should not be limited to selling owernship, they should also be licenseable wherefore then the owner and the creator gain royalty. 

Our goal is to implement the solution via:
- A license contract framework to link usage licenses of digital artifacts to NFTs
- Smart contracts to register contributions/commits or groups of contributions/commits as NFTs
- The NFTs of contributions can have an owner and a creator allowing developers to create sustainable developments
- The OCTL provides smart contracts to procure licenses for digital artifacts and to split the income between creators and owners of the different artifacts wherefore an usage license gets procured


# General remarks
The goal of this project is to leverage NFT technology to allow software developers to earn royalty for their creations.
We believe that this can make Open Source development more attactive and encourage knowlege sharing and collaboration worldwide.

The Open Contribution Token License (OCTL) terms and conditions apply as defined in the Open-Token-based-compensation-license file.
In short terms of the OCTL, the reader (you reading this text) is granted a license to test the OCTL and to study its contents, but not to copy it.
The license and software comes without warrenties and we remark that it is in active development and all interactions with the OCTL are considered test cases.


# Supporting the OCTL development

## Contributions
One can advance the OCTL and we welcome contributions and collaborations, provided they are compatible to the OCTL terms and conditions.

## Royalty donations
One can support the OCTL development by donating royalties for stying the OCTL to  
OCTL Project Donation Royalty address (ArbitriumOne/Ethereum mainnet):
0xf9f943202809545CDd8dcD95b8bBb314f7f8ee85

## Another innovative way 
Will be announced soon.
  

# Contract reacability
The OCTL can be reached for testing in different networks.

## Testing/Sepolina
Licenseable Contributions smart contract (Contributor Tokens):
Register commits and mint NFTs from the commits here
0x02125F01A5656C696fcBcCF44f0adB1d33f9C38E

License smart contract
Procure usage licenses for artifacts registered with the Licenseable Contributions contract with this contract.
0xCB56393c37A8091f07De6B1eE18D6ACb32A5E086

Granted License Contract:
NFT representing usage licenses that get issued by the License Contract
0xD2c4f7B25b0850e34674a2618A9bC9f2db15417B

## ArbitriumOne
Licenseable Contributions smart contract (Contributor Tokens):
Register commits and mint NFTs from the commits here
0x2D5486d6fbdea320fd1492975Dbe922359CA701femarks

License smart contract:
Procure usage licenses for artifacts registered with the Licenseable Contributions contract with this contract.
0x73E056059543c94a7c2B481536D565D6fDa8158A

Granted License Contract:
NFT representing usage licenses that get issued by the License Contract
0xb0B386f0c21c3ed9C8e195e0823e584b5F2e8F79


# Referencing the relevant contracts
One can test and contract the contracts as follows:

## Referencing the contracts in hardhat for testing
```
const { ethers } = require('hardhat');

async function main() {

[mintingaccount] = await ethers.getSigners();
  console.log(
    "Accessing contracts with the account:",
    await mintingaccount.getAddress()
  );

  const contractILicensableContributions = await artifacts.readArtifact("ILicensable");
  const contractContributionsInstance = new ethers.Contract("0x2D5486d6fbdea320fd1492975Dbe922359CA701f",
    contractILicensableContributions.abi, mintingaccount);

  const contractLicense = await artifacts.readArtifact("License");
  const contractLicenseInstance = new ethers.Contract("0x73E056059543c94a7c2B481536D565D6fDa8158A",
    contractILicensableContributions.abi, mintingaccount);
...
```

## Referening the contracts in a web 3 app
Import ethers and create a code object:
```
import Web3 from 'web3';
const web3 = new Web3(window.web3.currentProvider);

const { abiILicensable } = require('./ILicenseable.json');
var contractContributionsInstance = new web3.eth.Contract(abiILicensable, '0x2D5486d6fbdea320fd1492975Dbe922359CA701f');

const { abiLicense } = require('./License.json');
var contractLicenseInstance = new web3.eth.Contract(abiLicense, '0x73E056059543c94a7c2B481536D565D6fDa8158A');
...
```
# Resolving dependent commits and projects
NFT ids for commits can be resolved like follows:
```
contractContributionsInstance.resolveTokenForUri(
      ethers.toUtf8Bytes( "x-git-object:COMMIT ID"));
```

Dependent projects using project IDs can be resloved like follows:
```
contractContributionsInstance.resolveTokenForUri(
      ethers.toUtf8Bytes("x-octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57"));
```

# Single developer single digital artifact minting
Once a digital artifact is created a unique Id of it can be used to associate it to an NFT.
For source code this qill be commonly the commit id:

In case there is a single commit it can be simple be minted by specifing 4 main things:
- Unique commit ID
- The dependent digital artifacts (e.g. the commits that this commit is dependent on such as the last commit before or also libaries or other projects that are referenced)
- The creator
- The initial owner

Dependent contributions need to be licensed via the OCTL, too. Then they can be easily retrieved via:
``` 
dependentContribs= [contractContributionsInstance.resolveTokenForUri(ethers.toUtf8Bytes("x-octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57")),       contractContributionsInstance.resolveTokenForUri(ethers.toUtf8Bytes( "x-git-object:97d5dcb3c06b9fc157ea904b4a602f44f4bf2104"))]  
```

Then you can use the depending contributions in minting:

```
await contractContributionsInstance.mintSingle(
  // UNIQUE ID of the digital artifact or the group of digital artifacts
    ethers.toUtf8Bytes(<"x-digital-object:UUID"/"x-git-object:COMMIT ID">), 
    ethers.toUtf8Bytes(<"URL where the artifact can be found>),
    [<INITIAL OWNER ACCOUNT>, 
    <CREATOR ACCOUNT>],
    // depdendent contributions id as []
    [<dependentContribs>], 
    // the storypoints as integer muliplied by 100. 1 Hour is one story point
    <storypoints *100>, 
  );
```

# Surrogate (SID) Minting
In case artifacts do not have a unique identifier, like a commit id (one could imagine a collection of images or other record sets for Machine learning) one can use a unique surrogate ID to group one or more digital artifacts together which are associated with the respective NFT.

## SID Rules
- SIDs need to be unique.
- Only actual copyright owners or the owners or rights similar to the copyright owner or their empowered delegatees are allowed to associate digital artifacts with SIDs.
- Artifacts are allowed to be added to SIDs, but cannot be removed from those. 
- Additions to artifacts under a SID are not required to be associated with a SID. 
- Artifacts can be associated with multiple SIDs. 
- When usage licenses are procured for a SID the income is shared among the owners and creators wherefore the SID is dependent on. Hence, each time there is a new commit belonging to the SID one needs to add it as dependency to the SID when it should be included in the income share. Owners and creators adding SIDs to their work acknowlege and agree that there is no guarantee they will receive any kind of income share. 

## Generating valid SIDS
The easiest way to generate a colission free surrogate ID is to use a UUID generated by a program like uuigen in Linux. 
Subsequently the surrogate ID can be specified in in the digital artifacts belonging to the surrogate ID.

## Associating SIDS
Means to express this beloning can be special Exif tags for pictures with the surrogate ID, files enlisting which artifacts belong to the surrogate ID or simple source code tags. The easiest way is to add a OCTL-SID-INFO.txt file to your root project folder and and specify the details there. The specification could be like the following:

### General Digital Artifacts example
If a project is for example a collection of texts, pictures or similar one could just add a file OCTL-SID-INFO.txt to the root of your project wich could contain for example:

```
This project is licensed under the OPEN CONTRIBUTION TOKEN LICENSE;
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
https://github.com/open-compensation-token-license/license/blob/main/LICENSE.md


All the files in this folder and subfolders shall belong to the OCTL-SID: 7dec4673-5559-4895-9714-1cdd61a58b57

Usage Licenses can be obtained via the corresponding SIDs with the smart contracts of the OCTL.
```

Subsequently a licensee knows which artifacts are beloning to the NFT. 

For souce code an association with one or more SIDs
Alternatively the following code could do the trick:

```
/*******************************************************************************
 * Copyright (c) 2024 Tim Frey, Christian Schmitt. All rights reserved.
 *
 * Licensed under the OPEN COMPENSATION TOKEN LICENSE (the "License").
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   https://github.com/open-compensation-token-license/license/blob/main/LICENSE.md
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either expressed or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.

 /**
 * This a a simple example howto use Javadoc to associate different revisions for a file with one SID.
 * 
 * @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57
 **/
public class Myclass{
...
}
```

## MINTING SIDs
```
await contractContributionsInstance.mintSingle(
  // UNIQUE ID of the digital artifact or the group of digital artifacts
    ethers.toUtf8Bytes("x-octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57"), 
    ethers.toUtf8Bytes("MAIN REPOSITORY containing the different artifacts belonging together),
    [INITIAL OWNER ACCOUNT, 
    CREATOR ACCOUNT],
    [dependentContribs], 
    storypoints *100) 
```

One can see that there is an owner and a creator.
This is for the very reason that there could be a company wherefore a creator delivered the work. 
The creator will get the small creator royalty and the large will be delivered to the owner. 
The OCTL contracts set a default percentage for the creator. However a creator can lower the royalty percentage also appoint a beneficiary (by using other functions). 

## Associating subsequent contributions to the SID 
Often SIDs represent a project of an organization where the owner is the same and just the creators differ.
Hence, a parent SID can represent a version of a project and then different contributions are added.
Nesting is permitted when the owner of a new contribution matches the owner of the nesting parent.
```
await contractContributionsInstance.mintNested(
     // UNIQUE ID of the digital artifact or the group of digital artifacts
    ethers.toUtf8Bytes("x-git-object:LATEST COMMIT ID"),
    ethers.toUtf8Bytes("REPOSITORY URL LINKING To COMMIT"),
     // needs to match the nesting parent
    [INITIAL OWNER ACCOUNT,
    CREATOR ACCOUNT],
    [depdendentContribs], // depedendent contributions id as []
    storypoints *100,
    // the parent in which the NFT should be nested
    contractContributionsInstance.resolveTokenForUri(ethers.toUtf8Bytes("x-octl-sid:7dec4673-5559-4895-9714-1cdd61a58b57"))
    )
```

## Adding new contributions to the SID revenue share
Please note that adding a contribution to a SID does not make it a member in income distribution during license procurement.
In order to do that one has to add it as dependency to the SID after "Associating subsequent contributions to the SID" each time a new commit is done.
Adding a new commit is subsequently done by executing the following call:

```
contractContributionsInstance.addDependentContribution(contractContributionsInstance.resolveTokenForUri(ethers.toUtf8Bytes("x-git-object:LATEST COMMIT ID")));
```

## NOTE
Please note that we are open for proposals what is the best way howto generate and associate SIDs.

We are currently unclear if all thoughts and concepts of SIDs are final and we see ourselves some gaps here. 

Our core believe is that SIDs are required because creative work is often done in an incremental fashion and there needs to be an easy way to associate a non fungible set of unique non fungible artifats together to ease licensing and minting, but we require feedback.

Thereby we think in kind of a workflow where newly added incremental contributions can be easily be added to the same SIDs via automatic means. 
Or key goal is to make the SID concept covering 80 of the default cases and exclude rare cases to keep it simple. Hence, also commonts about simplifications are welcome.


# Procuring a usage license
Once artifacts are registered, procuring a usage license for code artifacts is straightforward for third parties:

## Concept of License procurement
One just calls the License contract with the artifacts one desires a license and the required amount of ether and then gets a Granted License NFT, representing a usage license for a year.

The License contract internally resolves all depenencies and enlistes them in the granted license.

## Workflow
Before the license one needs to determine the cost for the license. This works like follows:
```
contractLicenseInstance.evalLicenceCosts(<[contribution ids]>, <[OPT Variables]> );
```
One enters with two arrays as input. The contributions for which a license should be procured and optional variables (in later revisions he amount of workplaces and similar things can be specified via variables). The result is in ETH.

Once the license cost are clear one can procure a granted License NFT via sending the ETH to the following function:
```
contractLicenseInstance.procureLicense(<address to>, <[contribution ids]>, <[OPT Variables]>, <unit8 country of purchaser> )
```