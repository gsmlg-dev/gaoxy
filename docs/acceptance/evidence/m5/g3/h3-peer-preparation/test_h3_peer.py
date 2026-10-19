import asyncio,ast,pathlib,sys,unittest
root=pathlib.Path.cwd()/'integration/websocket_multiplexed'
sys.path.insert(0,str(root))

class H3PeerContracts(unittest.IsolatedAsyncioTestCase):
 def module(self):
  self.assertTrue((root/'h3_peer.py').exists(), 'independent H3 peer is not implemented')
  import h3_peer
  return h3_peer
 async def test_verified_h3_configuration(self):
  import ssl
  configuration=self.module().client_configuration('/tmp/m5-ca.pem')
  self.assertTrue(configuration.is_client)
  self.assertEqual(configuration.alpn_protocols,['h3'])
  self.assertEqual(configuration.server_name,'localhost')
  self.assertEqual(configuration.verify_mode,ssl.CERT_REQUIRED)
  self.assertEqual(configuration.cafile,'/tmp/m5-ca.pem')
 async def test_public_stream_allocation_keeps_two_websockets_distinct(self):
  module=self.module()
  from aioquic.quic.connection import QuicConnection
  from aioquic.h3.connection import Setting
  quic=QuicConnection(configuration=module.client_configuration('/tmp/m5-ca.pem'))
  peer=module.H3PeerProtocol(quic,port=443)
  one=peer.open_websocket('one',flush=False); two=peer.open_websocket('two',flush=False)
  self.assertEqual([one,two],[0,4])
  self.assertEqual(peer.http.sent_settings[Setting.ENABLE_CONNECT_PROTOCOL],1)
  self.assertEqual(peer.quic.get_next_available_stream_id(),8)
  self.assertEqual(set(peer.channels),{0,4})
 async def test_response_data_boundaries_and_fin_preserve_stream_messages(self):
  module=self.module()
  from aioquic.quic.connection import QuicConnection
  from aioquic.h3.events import HeadersReceived,DataReceived
  from wsproto.connection import Connection,ConnectionType
  from wsproto.events import TextMessage,BytesMessage
  peer=module.H3PeerProtocol(QuicConnection(configuration=module.client_configuration('/tmp/m5-ca.pem')),port=443)
  one=peer.open_websocket('one',flush=False); two=peer.open_websocket('two',flush=False)
  peer.handle_http_event(HeadersReceived(headers=[(b':status',b'200')],stream_id=one,stream_ended=False))
  self.assertNotIn(one,peer.ended)
  server1,server2=Connection(ConnectionType.SERVER),Connection(ConnectionType.SERVER)
  data=server1.send(TextMessage(data='one:hello'))
  peer.handle_http_event(DataReceived(data=data[:3],stream_id=one,stream_ended=False))
  peer.handle_http_event(DataReceived(data=server2.send(BytesMessage(data=b'two:binary')),stream_id=two,stream_ended=False))
  peer.handle_http_event(DataReceived(data=data[3:],stream_id=one,stream_ended=False))
  self.assertEqual(peer.channels[one].messages,[('text','one:hello')])
  self.assertEqual(peer.channels[two].messages,[('binary',b'two:binary')])
  peer.handle_http_event(DataReceived(data=b'',stream_id=one,stream_ended=True))
  self.assertIn(one,peer.ended)
  self.assertNotIn(two,peer.ended)
 async def test_public_quic_errors_reach_finite_waiter(self):
  module=self.module()
  from aioquic.quic.connection import QuicConnection
  from aioquic.quic.events import StreamReset
  peer=module.H3PeerProtocol(QuicConnection(configuration=module.client_configuration('/tmp/m5-ca.pem')),port=443)
  peer.quic_event_received(StreamReset(error_code=0x10c,stream_id=0))
  with self.assertRaises(AssertionError): await peer.wait(lambda:False)
 async def test_peer_does_not_access_dependency_private_attributes(self):
  self.module()
  tree=ast.parse((root/'h3_peer.py').read_text())
  bad=[node.attr for node in ast.walk(tree) if isinstance(node,ast.Attribute) and node.attr.startswith('_') and not node.attr.startswith('__')]
  self.assertEqual(bad,[])

if __name__=='__main__': unittest.main(verbosity=2)
