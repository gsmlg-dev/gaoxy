"""Proposal only: bounded scalar NetLog projection; never copies raw parameters."""
import json
import re
from pathlib import Path

MAX_BYTES = 8 * 1024 * 1024
MAX_EVENTS = 8192
_EVENT_NAMES = {
    'SOCKET_ALIVE', 'SOCKET_CLOSED', 'SOCKET_BYTES_SENT', 'SOCKET_BYTES_RECEIVED',
    'TCP_CONNECT', 'TCP_CONNECT_ATTEMPT', 'SSL_CONNECT', 'SSL_HANDSHAKE_ERROR',
    'SSL_SHUTDOWN', 'HTTP_STREAM_JOB_BOUND_TO_REQUEST',
    'HTTP_STREAM_REQUEST_BOUND_TO_JOB', 'HTTP2_STREAM',
}
_INT_KEYS = {
    'stream_id', 'last_stream_id', 'error_code', 'net_error', 'byte_count',
    'size', 'flags', 'active_streams', 'max_concurrent_streams',
}
_BOOL_KEYS = {'fin', 'end_stream'}
_ERROR_NAMES = {
    'NO_ERROR', 'PROTOCOL_ERROR', 'INTERNAL_ERROR', 'FLOW_CONTROL_ERROR',
    'SETTINGS_TIMEOUT', 'STREAM_CLOSED', 'FRAME_SIZE_ERROR', 'REFUSED_STREAM',
    'CANCEL', 'COMPRESSION_ERROR', 'CONNECT_ERROR', 'ENHANCE_YOUR_CALM',
    'INADEQUATE_SECURITY', 'HTTP_1_1_REQUIRED',
}


def _integer(value):
    return type(value) is int and -(2**63) <= value < 2**63


def _enum(value):
    return isinstance(value, str) and re.fullmatch(r'[A-Z][A-Z0-9_]{0,95}', value)


def _source(value, names):
    if not isinstance(value, dict):
        return None
    if not _integer(value.get('id')) or not _integer(value.get('type')):
        return None
    result = {'id': value['id'], 'type': value['type']}
    name = names.get(value['type'])
    if _enum(name):
        result['type_name'] = name
    return result


def _projection(event, event_names, source_names):
    if not isinstance(event, dict):
        return None
    name = event_names.get(event.get('type'))
    if not _enum(name) or not (name.startswith('HTTP2_SESSION') or name in _EVENT_NAMES):
        return None
    result = {'event': name}
    if _integer(event.get('phase')):
        result['phase'] = event['phase']
    time = event.get('time')
    if isinstance(time, str) and re.fullmatch(r'-?[0-9]{1,24}(?:\.[0-9]{1,9})?', time):
        result['time'] = time
    elif _integer(time):
        result['time'] = time
    source = _source(event.get('source'), source_names)
    if source is not None:
        result['source'] = source
    params = event.get('params')
    if isinstance(params, dict):
        projected = {key: params[key] for key in sorted(_INT_KEYS) if _integer(params.get(key))}
        projected.update({key: params[key] for key in sorted(_BOOL_KEYS) if type(params.get(key)) is bool})
        error_code = params.get('error_code')
        if isinstance(error_code, str) and error_code in _ERROR_NAMES:
            projected['error_code'] = error_code
        dependency = _source(params.get('source_dependency'), source_names)
        if dependency is not None:
            projected['source_dependency'] = dependency
        if projected:
            result['params'] = projected
    return result


def project_netlog(raw_path):
    """Read a finite prefix, including an unclosed live Chromium JSON array."""
    raw_path = Path(raw_path)
    result = {'schema': 1, 'status': 'NOT_STARTED', 'read_complete': False,
              'byte_limit': MAX_BYTES, 'event_limit': MAX_EVENTS, 'events': []}
    try:
        with raw_path.open('rb') as raw:
            data = raw.read(MAX_BYTES + 1)
    except FileNotFoundError:
        return result
    truncated = len(data) > MAX_BYTES
    data = data[:MAX_BYTES]
    result.update(status='INCOMPLETE_HEADER', read_bytes=len(data), byte_limit_reached=truncated)
    text = data.decode('utf-8', errors='ignore')
    decoder = json.JSONDecoder()
    header = re.match(r'\s*\{\s*"constants"\s*:\s*', text)
    if not header:
        result['status'] = 'UNRECOGNIZED_HEADER'
        return result
    try:
        constants, position = decoder.raw_decode(text, header.end())
    except json.JSONDecodeError:
        return result
    if not isinstance(constants, dict):
        result['status'] = 'UNRECOGNIZED_CONSTANTS'
        return result
    marker = re.match(r'\s*,\s*"events"\s*:\s*\[', text[position:])
    if not marker:
        result['status'] = 'INCOMPLETE_EVENT_HEADER'
        return result
    position += marker.end()
    event_names = {v: k for k, v in constants.get('logEventTypes', {}).items() if _integer(v)}
    source_names = {v: k for k, v in constants.get('logSourceType', {}).items() if _integer(v)}
    seen = 0
    while seen < MAX_EVENTS:
        whitespace = re.match(r'\s*', text[position:])
        position += whitespace.end()
        if position >= len(text):
            break
        if text[position] == ']':
            tail = text[position + 1:]
            result['read_complete'] = not truncated and re.fullmatch(r'\s*}\s*', tail) is not None
            break
        if text[position] == ',':
            position += 1
            continue
        try:
            event, end = decoder.raw_decode(text, position)
        except json.JSONDecodeError:
            break
        position = end
        seen += 1
        projected = _projection(event, event_names, source_names)
        if projected is not None:
            result['events'].append(projected)
    result.update(status='PROJECTED', scanned_events=seen, projected_events=len(result['events']),
                  event_limit_reached=seen == MAX_EVENTS)
    if seen == MAX_EVENTS:
        result['read_complete'] = False
    return result


def write_netlog_projection(raw_path, artifact_path):
    value = project_netlog(raw_path)
    with Path(artifact_path).open('x') as artifact:
        json.dump(value, artifact, indent=2, sort_keys=True)
        artifact.write('\n')
    return value
