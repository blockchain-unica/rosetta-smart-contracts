from dataclasses import dataclass
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from algokit_utils import (
    ApplicationSpecification,
)
from algosdk import transaction
from algosdk.abi import Method
from algosdk.v2client.algod import AlgodClient
from algosdk.atomic_transaction_composer import (
    ABIResult,
    AtomicTransactionComposer,
    AccountTransactionSigner,
    TransactionWithSigner,
)
from algosdk.transaction import SuggestedParams
from algosdk.v2client.algod import AlgodClient
from pyteal import ABIReturnSubroutine

from beaker.application import Application
from beaker.client import ApplicationClient
import algosdk

def set_fee(sp: SuggestedParams, fee=None):
    if fee:
        sp.flat_fee = True
        sp.fee = fee
    return sp

class WApp:
    SECRET_KEYS = [
        "ugEb7R8jAw8dRgiD/qskL1aG1dN8VgcLJTQiobLP58SExiUwUPRq2X7h0SEEgD5L7PMJehZqL4B//IHYtAJq8Q==",
        "tD+wIcVgrJTJ2KpNOUKo6lTTTOxWgiNp+jhMd5lb/OqnLxRSak/CGgIXbRobiB9/S5NJPrqJy6izFTwtPk7xYQ==",
    ]
    
    def __init__(self, app: ApplicationSpecification):
        self.app = app
        self.algod = AlgodClient('', 'https://testnet-api.algonode.cloud')
        self.clients = []
        self.id = None
        self.address = None
        
    def fetch_client(self) -> 'WApplicationClient':
        sk = self.SECRET_KEYS.pop()
        client = WApplicationClient(self, self.algod, self.app, sk)
        self.clients.append(client)
        return client
    
    def set_app(self, app_id, app_address):
        self.id = app_id
        self.address = app_address
        for client in self.clients:
            client.app_id = app_id
            
    @property
    def total_fees(self):
        return sum(map(lambda client: client.total_fees, self.clients))


class WApplicationClient:
    def __init__(
        self,
        wapp: WApp,
        client: AlgodClient,
        app: ApplicationSpecification | str | Path | Application,
        sk: str,
        *,
        app_id: int = 0,
        suggested_params: SuggestedParams | None = None,
    ):
        self.total_fees = 0
        self._wapp = wapp
        self.pk = algosdk.account.address_from_private_key(sk)
        self.sk = sk
        self.signer = AccountTransactionSigner(sk)
        
        self.app_client = ApplicationClient(client, app,
            app_id=app_id,
            signer=self.signer,
            sender=self.pk,
            suggested_params=suggested_params
        )
        
    def _add_fee_txid(self, tx_id: str):
        info = self._wapp.algod.pending_transaction_info(tx_id)
        if "grp" in info["txn"]["txn"]:
            grp = info["txn"]["txn"]["grp"]
            block = self._wapp.algod.block_info(info["confirmed-round"])
            txns = list(filter(lambda txn: "grp" in txn["txn"] and txn["txn"]["grp"] == grp, block["block"]["txns"]))
            itxns = sum(map(lambda txn: txn.get("dt", {}).get("itx", []), txns), [])
            self.total_fees += sum(map(lambda txn: txn["txn"].get("fee", 0), txns))
            self.total_fees += sum(map(lambda itxn: itxn["txn"].get("fee", 0), itxns))
        else:
            self.total_fees += info["txn"]["txn"].get("fee", 0)
            self.total_fees += sum(map(lambda itxn: itxn["txn"]["txn"].get("fee", 0), info.get("inner-txns", [])))
            
    @property
    def app_id(self):
        return self.app_client.app_id
        
    @app_id.setter
    def app_id(self, app_id):
        self.app_client.app_id = app_id

    def pay_txn(
        self,
        receiver,
        amt,
        sp=None,
        close_remainder_to=None,
        note=None,
        lease=None,
        rekey_to=None,
        flat_fee=None,
    ) -> TransactionWithSigner:
        sp = set_fee(sp or self._wapp.algod.suggested_params(), flat_fee)
        return TransactionWithSigner(signer=self.signer, txn=algosdk.transaction.PaymentTxn(
                sender=self.pk,
                sp=sp,
                receiver=receiver,
                amt=amt,
                close_remainder_to=close_remainder_to,
                note=note,
                lease=lease,
                rekey_to=rekey_to,
            ))
        
    def pay(
        self,
        receiver,
        amt,
        sp=None,
        close_remainder_to=None,
        note=None,
        lease=None,
        rekey_to=None,
        flat_fee=None,
    ):
        tx_id = self.exec_trans_with_signer(self.pay_txn(receiver, amt, sp, close_remainder_to, note, lease, rekey_to, flat_fee))
        self._add_fee_txid(tx_id)
        return tx_id

    def exec_trans_with_signer(self, txn: TransactionWithSigner):
        return self._wapp.algod.send_transactions(txn.signer.sign_transactions([txn.txn], [0]))

    def create(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        on_complete: transaction.OnComplete = transaction.OnComplete.NoOpOC,
        extra_pages: int | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> tuple[int, str, str]:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        app_id, app_address, tx_id = self.app_client.create(self.pk, self.signer, suggested_params, on_complete, extra_pages, **kwargs)
        self._wapp.set_app(app_id, app_address)
        self._add_fee_txid(tx_id)
        return app_id, app_address, tx_id

    def update(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> str:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        tx_id = self.app_client.update(self.pk, self.signer, suggested_params, **kwargs)
        self._add_fee_txid(tx_id)
        return tx_id
    
    def opt_in(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> str:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        tx_id = self.app_client.opt_in(self.pk, self.signer, suggested_params, **kwargs)
        self._add_fee_txid(tx_id)
        return tx_id

    def close_out(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> str:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        tx_id = self.app_client.close_out(self.pk, self.signer, suggested_params, **kwargs)
        self._add_fee_txid(tx_id)
        return tx_id
    
    def clear_state(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> str:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        tx_id = self.app_client.clear_state(self.pk, self.signer, suggested_params, **kwargs)
        self._add_fee_txid(tx_id)
        return tx_id
    
    def delete(
        self,
        suggested_params: transaction.SuggestedParams | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> str:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        tx_id = self.app_client.delete(self.pk, self.signer, suggested_params, **kwargs)
        self._add_fee_txid(tx_id)
        return tx_id
    
    def call(
        self,
        method: Method | ABIReturnSubroutine | str,
        suggested_params: transaction.SuggestedParams | None = None,
        on_complete: transaction.OnComplete = transaction.OnComplete.NoOpOC,
        accounts: list[str] | None = None,
        foreign_apps: list[int] | None = None,
        foreign_assets: list[int] | None = None,
        boxes: Sequence[tuple[int, bytes | bytearray | str | int]] | None = None,
        note: bytes | None = None,
        lease: bytes | None = None,
        rekey_to: str | None = None,
        atc: AtomicTransactionComposer | None = None,
        flat_fee: int | None = None,
        **kwargs: Any,  # noqa: ANN401
    ) -> ABIResult:
        suggested_params = set_fee(suggested_params or self._wapp.algod.suggested_params(), flat_fee)
        res = self.app_client.call(method, self.pk, self.signer, suggested_params, on_complete, accounts, foreign_apps, foreign_assets, boxes, note, lease, rekey_to, atc, **kwargs)
        self._add_fee_txid(res.tx_id)
        return res
