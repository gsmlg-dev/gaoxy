import pathlib,sys,unittest,json,tempfile
root=pathlib.Path.cwd()/'integration/websocket_multiplexed';sys.path.insert(0,str(root))
class BrowserContracts(unittest.TestCase):
 def module(self):
  self.assertTrue((root/'browser.py').exists(),'browser harness is not implemented')
  import browser
  return browser
 def test_ws_specific_correlation_requires_markers_and_actual_protocol(self):
  m=self.module(); clients=[dict(marker='run-1',url='wss://localhost:443/live/websocket?m5_ws=run-1',opened=True,path='/live/websocket'),dict(marker='run-2',url='wss://localhost:443/socket/websocket?m5_ws=run-2',opened=True,path='/socket/websocket')]
  receipts=[dict(event='websocket-upgrade',marker='run-1',version='HTTP/2',method='CONNECT',protocol='websocket',stream=1,connection='owner'),dict(event='websocket-upgrade',marker='run-2',version='HTTP/2',method='CONNECT',protocol='websocket',stream=3,connection='owner')]
  self.assertEqual(len(m.correlate_websockets('h2',clients,receipts)),2)
  with self.assertRaises(AssertionError):m.correlate_websockets('h2',clients,receipts[:1])
  with self.assertRaises(m.TransportMismatch):m.correlate_websockets('h2',clients,[dict(row,version='HTTP/1.1',method='GET',protocol=None) for row in receipts])
 def test_origin_rejection_requires_native_403_and_no_open(self):
  m=self.module(); client=dict(marker='origin-1',opened=False,error=True)
  receipt=dict(event='websocket-refusal',marker='origin-1',status=403,origin=['null'])
  self.assertEqual(m.validate_origin_rejection(client,[receipt]),receipt)
  for bad_client,bad_events in [(dict(client,opened=True),[receipt]),(dict(client,error=False),[receipt]),(client,[]),(client,[dict(receipt,status=500)]),(client,[dict(receipt,origin=[])]),(client,[receipt,dict(receipt,event='websocket-upgrade')])]:
   with self.assertRaises(AssertionError):m.validate_origin_rejection(bad_client,bad_events)
 def test_expected_origin_refusal_excludes_only_validated_receipt(self):
  m=self.module(); refusal=dict(event='websocket-refusal',marker='origin-1',status=403,origin=['null'])
  unexpected=dict(refusal,marker='other'); error=dict(event='websocket-error',marker='origin-1')
  self.assertEqual(m.native_upgrade_errors([refusal,unexpected,error],['origin-1']),[unexpected,error])
 def test_failed_native_upgrade_is_functional_failure(self):
  m=self.module(); result={'native_peer_qualified':True,'transport_mismatch':False,'error':'channel join failed','native_upgrade_errors':[{'status':500}]}
  self.assertEqual(m.failure_status(result),'FAIL')
  self.assertEqual(m.failure_status(dict(result,transport_mismatch=True,native_upgrade_errors=[])),'BLOCKED_ENV')
  self.assertEqual(m.failure_status(dict(result,transport_mismatch=True,native_peer_qualified=False,native_upgrade_errors=[])),'FAIL')
 def test_certificate_pin_and_chromium_args_are_scoped(self):
  m=self.module();args=m.chromium_arguments('h3',7443,'test-pin')
  self.assertIn('--ignore-certificate-errors-spki-list=test-pin',args)
  self.assertNotIn('--ignore-certificate-errors',args)
  self.assertIn('--enable-features=EnableWebsocketsOverHttp3',args)
  self.assertIn('--origin-to-force-quic-on=localhost:7443',args)
  self.assertIn('--disable-quic',m.chromium_arguments('h2',7443,'test-pin'))
 def test_case_completeness_cannot_pass_empty_partial_or_failed(self):
  m=self.module();good=[dict(name=name,status='PASS') for name in m.REQUIRED_CASES]
  m.validate_cases(good)
  for bad in [[],good[:-1],good+[good[0]],[dict(row,status='FAIL') for row in good]]:
   with self.assertRaises(AssertionError):m.validate_cases(bad)
 def test_url_marker_script_uses_native_websocket_and_tracks_normal_close(self):
  m=self.module();script=m.marker_script('run-example')
  self.assertIn('extends NativeWebSocket',script)
  self.assertIn('m5_ws',script)
  self.assertIn('run-example',script)
  self.assertIn('close',script)
if __name__=='__main__':unittest.main(verbosity=2)
