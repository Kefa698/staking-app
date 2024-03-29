const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { moveBlocks } = require("../utils/move-blocks")
const { moveTime } = require("../utils/move-time")

const SECONDS_IN_A_DAY = 86400
const SECONDS_IN_A_YEAR = 31449600

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Staking Unit Tests", function () {
          let staking, rewardToken, deployer, stakeAmount
          beforeEach(async () => {
              const accounts = await ethers.getSigners()
              deployer = accounts[0]
              await deployments.fixture(["RewardToken", "Staking"])
              staking = await ethers.getContract("Staking")
              rewardToken = await ethers.getContract("RewardToken")
              stakeAmount = ethers.utils.parseEther("100000")
          })

          describe("constructor", () => {
              it("sets the rewards token address correctly", async () => {
                  const response = await staking.s_rewardToken()
                  assert.equal(response, rewardToken.address)
              })
          })
          describe("rewardPerToken", () => {
              it("Returns the reward amount of 1 token based time spent locked up", async () => {
                  await rewardToken.approve(staking.address, stakeAmount)
                  await staking.stake(stakeAmount)
                  await moveTime(SECONDS_IN_A_DAY)
                  await moveBlocks(1)
                  let reward = await staking.rewardPerToken()
                  let expectedReward = "86"
                  assert.equal(reward.toString(), expectedReward)

                  await moveTime(SECONDS_IN_A_YEAR)
                  await moveBlocks(1)
                  reward = await staking.rewardPerToken()
                  expectedReward = "31536"
                  assert.equal(reward.toString(), expectedReward)
              })
          })
          describe("stake", () => {
              it("Moves tokens from the user to the staking contract", async () => {
                  await rewardToken.approve(staking.address, stakeAmount)
                  await staking.stake(stakeAmount)
                  await moveTime(SECONDS_IN_A_DAY)
                  await moveBlocks(1)
                  const earned = await staking.earned(deployer.address)
                  const expectedEarned = "8600000"
                  assert.equal(expectedEarned, earned.toString())
              })
          })
          describe("withdraw", () => {
              it("Moves tokens from the staking contract to the user", async () => {
                  await rewardToken.approve(staking.address, stakeAmount)
                  await staking.stake(stakeAmount)
                  await moveTime(SECONDS_IN_A_DAY)
                  await moveBlocks(1)
                  const balanceBefore = await rewardToken.balanceOf(deployer.address)
                  await staking.withdraw(stakeAmount)
                  const balanceAfter = await rewardToken.balanceOf(deployer.address)
                  const earned = await staking.earned(deployer.address)
                  const expectedEarned = "8600000"
                  assert.equal(expectedEarned, earned.toString())
                  assert.equal(balanceBefore.add(stakeAmount).toString(), balanceAfter.toString())
              })
          })
          describe("claimReward", () => {
              it("Users can claim their rewards", async () => {
                  await rewardToken.approve(staking.address, stakeAmount)
                  await staking.stake(stakeAmount)
                  await moveTime(SECONDS_IN_A_DAY)
                  await moveBlocks(1)
                  const earned = await staking.earned(deployer.address)
                  const balanceBefore = await rewardToken.balanceOf(deployer.address)
                  await staking.claim()
                  const balanceAfter = await rewardToken.balanceOf(deployer.address)
                  assert(balanceBefore.add(earned).toString()== balanceAfter.toString())
              })
          })
      })
