const abi = require('../out/PoW.sol/ProofOfWork.json').abi

const ethers = require('ethers')

const findSecret = async () => {
  const contractAddress = "0x8c941d5f5845649b91526666d96945896a7a99b5"
  const msgSender = "YOUR_WALLET_ADDRESS"
  const provider = new ethers.JsonRpcProvider('https://mainnet.base.org')
  const contract = new ethers.Contract(contractAddress, abi, provider)
  const round = await contract.round()
  const prevBlockHash = await contract.prevBlockHash()
  const currentThreshold = await contract.currentThreshold()
  let isFirst = true
  let results
  let secret = 0 
  while(isFirst || results >= currentThreshold) {
    isFirst = false
    results = ethers.solidityPackedKeccak256(
      [ "address", "uint256", "bytes32", "uint256"], 
      [ msgSender, round, prevBlockHash, ++secret ]
    )
    if (secret % 100000 === 0) console.log('hashing...')
  }
  console.log({
    secret,
    results,
    currentThreshold,
    prevBlockHash
  })

  const signer = new ethers.Wallet('YOUR_PRIV_KEY', provider)
  const contractWithSigner = contract.connect(signer)
  const lastMintAt = await contract.lastMintedAt()
  const tx = await contractWithSigner.mint(msgSender, secret)
  await tx.wait()
  console.log({
    date: Date.now()/1000,
    lastMintAt,
    deltaT: BigInt(parseInt(Date.now()/1000)) - lastMintAt,
    newBalance: await contract.balanceOf(msgSender)
  })
}

const mintIndefinetely = async () => {
  while(true) {
    await findSecret()
  }
}

mintIndefinetely()