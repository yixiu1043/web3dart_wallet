import 'package:example/const/address.dart';
import 'package:example/utils/store.dart';
import 'package:example/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart';
import 'dart:math' as math;

class SwapPage extends StatefulWidget {
  const SwapPage({Key? key}) : super(key: key);

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  @override
  void initState() {
    _allowance(Store.web3Client, Store.privateKey);
    super.initState();
  }

  void _allowance(Web3Client web3client, wallet.PrivateKey privateKey) async {
    final erc20 = await Utils.instance.getLocalJson('Erc20');
    final usdtContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'usdt'),
      EthereumAddress.fromHex(USDTAddress),
    );
    final wbnbContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'bnb'),
      EthereumAddress.fromHex(WBNBAddress),
    );
    final yxContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'yx'),
      EthereumAddress.fromHex(YXAddress),
    );

    /// 查询授权
    final allowanceUsdt = await web3client.call(
      contract: usdtContract,
      function: usdtContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(Store.walletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    final allowanceWbnb = await web3client.call(
      contract: wbnbContract,
      function: wbnbContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(Store.walletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    final allowanceYx = await web3client.call(
      contract: yxContract,
      function: yxContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(Store.walletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    if (allowanceUsdt[0] == BigInt.zero) {
      _approve(web3client, privateKey, usdtContract);
    }

    if (allowanceWbnb[0] == BigInt.zero) {
      _approve(web3client, privateKey, wbnbContract);
    }

    if (allowanceYx[0] == BigInt.zero) {
      _approve(web3client, privateKey, yxContract);
    }

    print('allowanceUsdt: ${allowanceUsdt}');
    print('allowanceUsdt: ${allowanceUsdt[0] > BigInt.zero}');
    print('allowanceWbnb: ${allowanceWbnb}');
    print('allowanceYx: ${allowanceYx}');
  }

  void _approve(Web3Client web3client, wallet.PrivateKey privateKey,
      DeployedContract contract) async {
    final chainId = await web3client.getChainId();
    final tx = await web3client.sendTransaction(
      EthPrivateKey.fromInt(privateKey.value),
      Transaction.callContract(
        contract: contract,
        function: contract.function('approve'),
        parameters: [
          EthereumAddress.fromHex(PancakeRouterAddress),
          BigInt.from(10).pow(30)
        ],
        value: EtherAmount.fromBigInt(EtherUnit.ether, BigInt.zero),
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $tx');
  }

  void _swapExactETHForTokens(
      Web3Client web3client, wallet.PrivateKey privateKey) async {
    final chainId = await web3client.getChainId();
    final pancakeFactory = await Utils.instance.getLocalJson('PancakeFactory');
    final pancakeRouterAbi = await Utils.instance.getLocalJson('PancakeRouter');

    final pancakeFactoryContract = DeployedContract(
      ContractAbi.fromJson(pancakeFactory, 'PancakeFactory'),
      EthereumAddress.fromHex(PancakeFactoryAddress),
    );
    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouterAbi, 'PancakeRouter'),
      EthereumAddress.fromHex(PancakeRouterAddress),
    );

    /// 获取交易对地址
    // final pairAddress = await _web3Client.call(
    //   contract: pancakeFactoryContract,
    //   function: pancakeFactoryContract.function('getPair'),
    //   params: [
    //     EthereumAddress.fromHex(WBNBAddress),
    //     EthereumAddress.fromHex(USDTAddress),
    //   ],
    // );
    // print('pairAddress: ${pairAddress}');

    /// 获取输出
    // final amountsOut = await _web3Client.call(
    //   contract: pancakeRouterContract,
    //   function: pancakeRouterContract.function('getAmountsOut'),
    //   params: [
    //     BigInt.from(0.001 * math.pow(10, 18)),
    //     [
    //       EthereumAddress.fromHex(WBNBAddress),
    //       EthereumAddress.fromHex(USDTAddress),
    //     ]
    //   ],
    // );
    // print('getAmountsOut: ${amountsOut}');
    const amountInEth = 0.01;
    final amountIn = EtherAmount.fromBigInt(
      EtherUnit.wei,
      BigInt.from(amountInEth * math.pow(10, 18)),
    );
    final amountOutMin = BigInt.zero;

    final tx = await web3client.sendTransaction(
      EthPrivateKey.fromInt(privateKey.value),
      Transaction.callContract(
        contract: pancakeRouterContract,
        function: pancakeRouterContract.function('swapExactETHForTokens'),
        parameters: [
          amountOutMin,
          [
            EthereumAddress.fromHex(WBNBAddress),
            EthereumAddress.fromHex(USDTAddress),
          ],
          EthereumAddress.fromHex(Store.walletAddress),
          BigInt.from(DateTime.now()
              .add(const Duration(minutes: 20))
              .millisecondsSinceEpoch),
        ],
        value: amountIn,
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $tx');

    showAlertDialog();
  }

  void _swapExactTokensForTokens(
      Web3Client web3client, wallet.PrivateKey privateKey) async {
    final chainId = await web3client.getChainId();
    final pancakeRouter = await Utils.instance.getLocalJson('PancakeRouter');

    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouter, 'PancakeRouter'),
      EthereumAddress.fromHex(PancakeRouterAddress),
    );

    final amountIn = BigInt.from(1 * math.pow(10, 18));

    final tx = await web3client.sendTransaction(
      EthPrivateKey.fromInt(privateKey.value),
      Transaction.callContract(
        contract: pancakeRouterContract,
        function: pancakeRouterContract.function('swapExactTokensForTokens'),
        parameters: [
          amountIn,
          BigInt.zero,
          [
            EthereumAddress.fromHex(USDTAddress),
            EthereumAddress.fromHex(YXAddress),
          ],
          EthereumAddress.fromHex(Store.walletAddress),
          BigInt.from(DateTime.now()
              .add(const Duration(minutes: 20))
              .millisecondsSinceEpoch),
        ],
      ),
      chainId: chainId.toInt(),
    );

    print('Transaction hash: $tx');
    showAlertDialog();
  }

  void showAlertDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          //可滑动
          content: const Text('成功！'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('闪兑'),
      ),
      body: Center(
        child: Column(
          children: [
            // ElevatedButton(
            //   onPressed: _allowance,
            //   child: const Text('查询Erc20授权'),
            // ),
            // ElevatedButton(
            //   onPressed: _approve,
            //   child: const Text('Erc20代币授权'),
            // ),
            ElevatedButton(
              onPressed: () =>
                  _swapExactETHForTokens(Store.web3Client, Store.privateKey),
              child: const Text('兑换0.01BNB为USDT'),
            ),
            ElevatedButton(
              onPressed: () =>
                  _swapExactTokensForTokens(Store.web3Client, Store.privateKey),
              child: const Text('兑换1USDT为1YX'),
            ),
          ],
        ),
      ),
    );
  }
}
