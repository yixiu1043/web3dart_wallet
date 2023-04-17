import 'package:example/const/address.dart';
import 'package:example/utils/store.dart';
import 'package:example/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart';
import 'dart:math' as math;

class TransferPage extends StatefulWidget {
  const TransferPage({Key? key}) : super(key: key);

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  late final TextEditingController _textEditingController;

  @override
  void initState() {
    _textEditingController = TextEditingController();
    super.initState();
  }

  void _sendTransactionBnb(
      Web3Client web3client, wallet.PrivateKey privateKey) async {
    final chainId = await web3client.getChainId();
    final toAddress = _textEditingController.text; // 转出地址

    const amountInEth = 0.01; // 0.01ETH
    final amountInWei = EtherAmount.fromBigInt(
      EtherUnit.wei,
      BigInt.from(amountInEth * math.pow(10, 18)),
    );
    await web3client.sendTransaction(
      EthPrivateKey.fromInt(privateKey.value),
      Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: amountInWei,
        // value: EtherAmount.get(EtherUnit.ether, 0.01),
      ),
      chainId: chainId.toInt(),
    );
    showAlertDialog();
  }

  void _sendTransactionUsdt(
      Web3Client web3client, wallet.PrivateKey privateKey) async {
    final chainId = await web3client.getChainId();
    final toAddress = _textEditingController.text; // 转出地址

    final erc20 = await Utils.instance.getLocalJson('Erc20');
    final usdtContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'usdt'),
      EthereumAddress.fromHex(USDTAddress),
    );
    await web3client.sendTransaction(
      EthPrivateKey.fromInt(privateKey.value),
      Transaction.callContract(
        contract: usdtContract,
        function: usdtContract.function('transfer'),
        parameters: [
          EthereumAddress.fromHex(toAddress),
          BigInt.from(1 * math.pow(10, 18)),
        ],
      ),
      chainId: chainId.toInt(),
    );
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
        title: const Text('转账'),
      ),
      body: Center(
        child: Column(
          children: [
            TextField(
              controller: _textEditingController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '请输入地址',
                counterText: '',
                isDense: true,
                labelText: '转出地址',
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  _sendTransactionBnb(Store.web3Client, Store.privateKey),
              child: const Text('转出0.01BNB'),
            ),
            ElevatedButton(
              onPressed: () =>
                  _sendTransactionUsdt(Store.web3Client, Store.privateKey),
              child: const Text('转出1USDT'),
            ),
          ],
        ),
      ),
    );
  }
}
