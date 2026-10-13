#!/usr/bin/env python3
"""Independent wire vectors for the bounded H3 HEAD/304 response decoder."""
import unittest

import pylsqpack

from peer import BodylessResponseDecoder, state


STATIC_200 = b"\x00\x00\xd9"
LITERAL_X_Y = b"\x21\x78\x01\x79"
# Literal field name length14: saturated three-bit prefix7, continuation7.
CONTENT_LENGTH_7 = b"\x27\x07content-length\x01\x37"


def varint(value, width=None):
    if width is None:
        width = next(size for size in (1, 2, 4, 8) if value < 1 << (size * 8 - 2))
    prefix = {1: 0, 2: 1, 4: 2, 8: 3}[width]
    return (value | (prefix << (width * 8 - 2))).to_bytes(width, "big")


def frame(kind, payload, type_width=None, length_width=None):
    return varint(kind, type_width) + varint(len(payload), length_width) + payload


class BodylessResponseDecoderTest(unittest.TestCase):
    def decoder(self):
        response = state()
        decoder = BodylessResponseDecoder(0, response)
        self.assertEqual(decoder.max_bytes, 65_536)
        return decoder, response

    def assert_complete(self, response, headers):
        self.assertEqual(response["headers"], [headers])
        self.assertEqual(bytes(response["body"]), b"")
        self.assertTrue(response["ended"])
        wire = response["bodyless_wire"]
        self.assertEqual(wire["decoder"], "raw_static_qpack")
        self.assertEqual(wire["fin_count"], 1)
        self.assertEqual(wire["data_frames"], 0)
        self.assertEqual(wire["data_bytes"], 0)

    def test_static_headers_require_actual_fin(self):
        decoder, response = self.decoder()
        decoder.feed(frame(1, STATIC_200))
        self.assertEqual(response["headers"], [[(b":status", b"200")]])
        self.assertFalse(response["ended"])
        self.assertEqual(response["bodyless_wire"]["fin_count"], 0)
        decoder.feed(b"", fin=True)
        self.assert_complete(response, [(b":status", b"200")])

    def test_independent_literal_field_vector(self):
        decoder, response = self.decoder()
        decoder.feed(frame(1, b"\x00\x00" + LITERAL_X_Y), fin=True)
        self.assert_complete(response, [(b"x", b"y")])

    def test_every_split_of_multibyte_type_length_and_headers_payload(self):
        block = STATIC_200 + LITERAL_X_Y * 16
        wire = frame(1, block, type_width=2, length_width=2)
        expected = [(b":status", b"200")] + [(b"x", b"y")] * 16
        for split in range(1, len(wire)):
            with self.subTest(split=split):
                decoder, response = self.decoder()
                decoder.feed(wire[:split])
                self.assertFalse(response["ended"])
                decoder.feed(wire[split:], fin=True)
                self.assert_complete(response, expected)

    def test_single_byte_fragments_with_separate_fin(self):
        decoder, response = self.decoder()
        wire = frame(1, STATIC_200 + LITERAL_X_Y, type_width=2, length_width=2)
        for byte in wire:
            decoder.feed(bytes([byte]))
            self.assertFalse(response["ended"])
        decoder.feed(b"", fin=True)
        self.assert_complete(response, [(b":status", b"200"), (b"x", b"y")])

    def test_head_and_304_content_length_metadata_survives_zero_data_fin(self):
        for status, indexed in ((b"200", b"\xd9"), (b"304", b"\xda")):
            with self.subTest(status=status):
                decoder, response = self.decoder()
                block = b"\x00\x00" + indexed + CONTENT_LENGTH_7
                decoder.feed(frame(1, block), fin=True)
                self.assert_complete(response, [(b":status", status), (b"content-length", b"7")])

    def test_multibyte_unknown_frame_can_be_discarded_at_every_split(self):
        wire = frame(1, STATIC_200) + frame(0x40, b"x" * 65)
        for split in range(1, len(wire)):
            with self.subTest(split=split):
                decoder, response = self.decoder()
                decoder.feed(wire[:split])
                self.assertFalse(response["ended"])
                decoder.feed(wire[split:], fin=True)
                self.assert_complete(response, [(b":status", b"200")])

    def test_positive_data_frame_is_rejected(self):
        decoder, response = self.decoder()
        decoder.feed(frame(1, STATIC_200))
        with self.assertRaisesRegex(AssertionError, "bodyless DATA"):
            decoder.feed(frame(0, b"x"), fin=True)
        self.assertFalse(response["ended"])

    def test_zero_length_data_frame_is_rejected(self):
        decoder, response = self.decoder()
        decoder.feed(frame(1, STATIC_200))
        with self.assertRaisesRegex(AssertionError, "bodyless DATA"):
            decoder.feed(frame(0, b""), fin=True)
        self.assertFalse(response["ended"])

    def test_partial_multibyte_type_at_fin_is_rejected(self):
        decoder, _ = self.decoder()
        with self.assertRaisesRegex(AssertionError, "partial frame at FIN"):
            decoder.feed(b"\x40", fin=True)

    def test_partial_multibyte_length_at_fin_is_rejected(self):
        decoder, _ = self.decoder()
        with self.assertRaisesRegex(AssertionError, "partial frame at FIN"):
            decoder.feed(b"\x01\x40", fin=True)

    def test_every_truncated_headers_payload_at_fin_is_rejected(self):
        wire = frame(1, STATIC_200 + LITERAL_X_Y)
        for prefix in range(2, len(wire)):
            with self.subTest(prefix=prefix):
                decoder, _ = self.decoder()
                with self.assertRaisesRegex(AssertionError, "partial frame at FIN"):
                    decoder.feed(wire[:prefix], fin=True)

    def test_nonzero_required_insert_count_is_rejected(self):
        decoder, _ = self.decoder()
        with self.assertRaisesRegex(AssertionError, "unexpected dynamic QPACK"):
            decoder.feed(frame(1, b"\x01\x00"), fin=True)

    def test_dynamic_indexed_reference_is_rejected(self):
        decoder, _ = self.decoder()
        with self.assertRaises((AssertionError, pylsqpack.DecompressionFailed, pylsqpack.StreamBlocked)):
            decoder.feed(frame(1, b"\x00\x00\x80"), fin=True)

    def test_declared_frame_over_limit_is_rejected_before_payload(self):
        decoder, _ = self.decoder()
        with self.assertRaisesRegex(AssertionError, "bodyless frame/carry limit"):
            decoder.feed(varint(0x40) + varint(65_537))

    def test_fragmented_carry_over_limit_is_rejected(self):
        decoder, _ = self.decoder()
        decoder.feed(varint(0x40) + varint(65_536) + b"x" * 32_768)
        with self.assertRaisesRegex(AssertionError, "bodyless frame/carry limit"):
            decoder.feed(b"x" * 32_768)

    def test_repeated_headers_are_rejected(self):
        decoder, response = self.decoder()
        decoder.feed(frame(1, STATIC_200))
        with self.assertRaisesRegex(AssertionError, "repeated HEADERS"):
            decoder.feed(frame(1, STATIC_200), fin=True)
        self.assertFalse(response["ended"])

    def test_known_forbidden_response_frames_are_rejected(self):
        for kind in (2, 3, 4, 5, 7, 13, 14):
            with self.subTest(kind=kind):
                decoder, response = self.decoder()
                decoder.feed(frame(1, STATIC_200))
                with self.assertRaisesRegex(AssertionError, "unexpected response frame"):
                    decoder.feed(frame(kind, b""), fin=True)
                self.assertFalse(response["ended"])


if __name__ == "__main__":
    unittest.main()
