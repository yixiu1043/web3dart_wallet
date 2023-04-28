import 'package:example/const/address.dart';
import 'package:example/utils/store.dart';
import 'package:example/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'dart:math' as math;

class TransactionPage extends StatefulWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  @override
  void initState() {
    // _getUSDTTransaction();
    super.initState();
  }

  void _getUSDTTransaction() async {
    print('BlockNum.genesis() ----------- ${BlockNum.genesis()}');
    print('BlockNum.current() ----------- ${BlockNum.current()}');
    print('Store.walletAddress ----------- ${Store.walletAddress}');

    /// https://github.com/simolus3/web3dart/issues/56
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
    final usdtTransferEvent = usdtContract.event('Transfer');
    final wbnbTransferEvent = wbnbContract.event('Transfer');
    final yxTransferEvent = yxContract.event('Transfer');

    print(bytesToHex(wbnbTransferEvent.signature,
        padToEvenLength: true, include0x: true, forcePadLength: 64));
    print(bytesToHex(hexToBytes(Store.walletAddress),
        padToEvenLength: true, include0x: true, forcePadLength: 64));

    /// 获取发送的USDT
    final sendList = await Store.web3Client.getLogs(FilterOptions(
      fromBlock: const BlockNum.genesis(),
      toBlock: const BlockNum.current(),
      address: EthereumAddress.fromHex(USDTAddress),
      topics: [
        [
          bytesToHex(usdtTransferEvent.signature,
              padToEvenLength: true, include0x: true, forcePadLength: 64)
        ],
        [
          bytesToHex(hexToBytes(Store.walletAddress),
              padToEvenLength: true, include0x: true, forcePadLength: 64)
        ],
        [],
      ],
    ));
    print(sendList.length);
    sendList.forEach((element) async {
      print('element ----------- ${element.transactionHash}');
      final receipt = await Store.web3Client
          .getTransactionReceipt(element.transactionHash ?? '');
      print('receipt ----------- ${receipt}');
      print('to ----------- ${receipt?.to}');
      print('amount ----------- ${hexToInt(receipt?.logs[0].data ?? '')} wei');
    });

    return;
    /// 获取收到的USDT
    final receiveList = await Store.web3Client.getLogs(FilterOptions(
      fromBlock: const BlockNum.genesis(),
      toBlock: const BlockNum.current(),
      address: EthereumAddress.fromHex(USDTAddress),
      topics: [
        [
          bytesToHex(usdtTransferEvent.signature,
              padToEvenLength: true, include0x: true, forcePadLength: 64)
        ],
        [],
        [bytesToHex(hexToBytes(Store.walletAddress), padToEvenLength: true, include0x: true, forcePadLength: 64)],
      ],
    ));
    print(receiveList.length);
    receiveList.forEach((element) async {
      print('element ----------- ${element.transactionHash}');
      final receipt = await Store.web3Client
          .getTransactionReceipt(element.transactionHash ?? '');
      print('receipt ----------- ${receipt}');
    });
    // final list = await Store.web3Client.getLogs(FilterOptions.events(
    //   contract: usdtContract,
    //   event: ContractEvent(false, 'Transfer', []),
    //   fromBlock: const BlockNum.genesis(),
    //   toBlock: const BlockNum.current(),
    // ));

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('转账'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _getUSDTTransaction,
              child: const Text('Erc20代币交易记录'),
            ),
          ],
        ),
      ),
    );
  }
}
