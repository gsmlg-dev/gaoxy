import importlib.util,pathlib,sys,unittest
root=pathlib.Path.cwd()/"integration/websocket_multiplexed"
sys.path.insert(0,str(root))

class PeerContracts(unittest.TestCase):
 def test_required_cases_reject_zero_missing_duplicate_and_failed(self):
  self.assertTrue((root/'h2_peer.py').exists(), 'independent H2 peer is not implemented')
  import h2_peer
  good=[{'name':name,'status':'PASS'} for name in h2_peer.REQUIRED_CASES]
  h2_peer.validate_results(good)
  for bad in [[],good[:-1],good+[good[0]],[dict(row,status='FAIL') if n==0 else row for n,row in enumerate(good)]]:
   with self.assertRaises(AssertionError): h2_peer.validate_results(bad)
 def test_http_data_boundaries_preserve_websocket_events(self):
  self.assertTrue((root/'h2_peer.py').exists(), 'independent H2 peer is not implemented')
  from h2_peer import WebSocketChannel
  from wsproto.connection import Connection,ConnectionType
  from wsproto.events import TextMessage,BytesMessage,Ping,CloseConnection
  channel=WebSocketChannel('one')
  server=Connection(ConnectionType.SERVER)
  data=server.send(TextMessage(data='one:hello'))+server.send(BytesMessage(data=b'one:binary'))
  channel.feed(data[:3]); channel.feed(data[3:])
  self.assertEqual(channel.messages,[('text','one:hello'),('binary',b'one:binary')])
  channel.feed(server.send(Ping(payload=b'probe')))
  self.assertEqual(channel.controls[0].payload,b'probe')
 def test_h2_connect_and_data_use_stream_ids_independently(self):
  self.assertTrue((root/'h2_peer.py').exists(), 'independent H2 peer is not implemented')
  from h2_peer import H2Peer
  from h2.connection import H2Connection
  from h2.config import H2Configuration
  from h2.events import RequestReceived
  from h2.settings import SettingCodes
  peer=H2Peer('h2c',port=80)
  server=H2Connection(config=H2Configuration(client_side=False))
  server.initiate_connection(); server.update_settings({SettingCodes.ENABLE_CONNECT_PROTOCOL:1})
  server.receive_data(peer.h2.data_to_send()); peer.feed(server.data_to_send())
  first=peer.open_websocket('one',flush=False); second=peer.open_websocket('two',flush=False)
  self.assertNotEqual(first,second)
  events=server.receive_data(peer.h2.data_to_send())
  requests=[e for e in events if isinstance(e,RequestReceived)]
  self.assertEqual([e.stream_id for e in requests],[first,second])
  for e in requests:
   self.assertIn((b':method',b'CONNECT'),e.headers)
   self.assertIn((b':protocol',b'websocket'),e.headers)
   self.assertIsNone(e.stream_ended)


 def test_server_receipts_require_actual_native_deadlines_and_same_connection(self):
  from run import validate_server_receipts
  opens=[dict(event='websocket-open',connection='owner',stream=i,method='CONNECT',protocol='websocket',version='HTTP/2',original_deadline=100,requested_websocket_deadline=1000,accepted_websocket_deadline=1000) for i in [1,3]]
  siblings=[dict(event='http-request',connection='owner',path=p) for p in ['/sibling','/after-close']]
  ends=[dict(event='websocket-terminated',label=p) for p in ['one','two']]
  validate_server_receipts(opens+siblings+ends+[dict(event='post-deadline-message',stream=1,original_deadline=100,observed_at=200)])
  for invalid in [opens[:1]+siblings+ends, [dict(opens[0],accepted_websocket_deadline=100),opens[1]]+siblings+ends, opens+[dict(siblings[0],connection='another'),siblings[1]]+ends]:
   with self.assertRaises(AssertionError): validate_server_receipts(invalid)
  with self.assertRaises(AssertionError): validate_server_receipts(opens+siblings+ends+[dict(event='post-deadline-message',stream=1,original_deadline=100,observed_at=99)])

if __name__=='__main__': unittest.main(verbosity=2)
