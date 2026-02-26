import 'dart:convert';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

class RsaKeyHelper {
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        SecureRandom('Fortuna')..seed(KeyParameter(_seed())),
      ));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static Uint8List _seed() {
    final random = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256),
      )));
    return random.nextBytes(32);
  }

  /// Encode an RSA public key in SubjectPublicKeyInfo (X.509) PEM format,
  /// which is what OpenSSL and Discourse expect.
  static String encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());

    final publicKeyBitString = ASN1Sequence()
      ..add(ASN1Integer(publicKey.modulus!))
      ..add(ASN1Integer(publicKey.exponent!));

    final publicKeySeq = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(ASN1BitString(
          Uint8List.fromList(publicKeyBitString.encodedBytes)));

    final encoded = base64Encode(publicKeySeq.encodedBytes);
    return _wrapPem('PUBLIC KEY', encoded);
  }

  static String encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final seq = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(privateKey.modulus!))
      ..add(ASN1Integer(privateKey.publicExponent!))
      ..add(ASN1Integer(privateKey.privateExponent!))
      ..add(ASN1Integer(privateKey.p!))
      ..add(ASN1Integer(privateKey.q!))
      ..add(ASN1Integer(
          privateKey.privateExponent! % (privateKey.p! - BigInt.one)))
      ..add(ASN1Integer(
          privateKey.privateExponent! % (privateKey.q! - BigInt.one)))
      ..add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

    final encoded = base64Encode(seq.encodedBytes);
    return _wrapPem('RSA PRIVATE KEY', encoded);
  }

  static Uint8List decrypt(RSAPrivateKey privateKey, Uint8List encrypted) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return _processInBlocks(cipher, encrypted);
  }

  static Uint8List _processInBlocks(
      AsymmetricBlockCipher engine, Uint8List input) {
    final inputBlockSize = engine.inputBlockSize;
    final output = BytesBuilder();

    for (var i = 0; i < input.length; i += inputBlockSize) {
      final end =
          (i + inputBlockSize < input.length) ? i + inputBlockSize : input.length;
      output.add(engine.process(input.sublist(i, end)));
    }
    return output.toBytes();
  }

  static String _wrapPem(String label, String base64Data) {
    final lines = <String>[];
    for (var i = 0; i < base64Data.length; i += 64) {
      lines.add(base64Data.substring(
          i, i + 64 > base64Data.length ? base64Data.length : i + 64));
    }
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----';
  }
}
