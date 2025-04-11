require 'openssl'
require 'base64'

class AesHelper
  # AES-256-CBC 加密（输出 Base64 编码字符串）
  def self.aes_encrypt(plaintext, key, iv)
    key = Base64.strict_decode64(key)

    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    encrypted = cipher.update(plaintext) + cipher.final
    Base64.strict_encode64(iv + encrypted) # 将 IV 和密文拼接后编码
  end

  # AES-256-CBC 解密（输入 Base64 编码字符串）
  def self.aes_decrypt(ciphertext, key)
    key = Base64.strict_decode64(key)

    decoded = Base64.strict_decode64(ciphertext)
    iv = decoded[0...16] # 提取前16字节作为 IV
    encrypted = decoded[16..-1]

    decipher = OpenSSL::Cipher.new('AES-256-CBC')
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv

    res = decipher.update(encrypted) + decipher.final
    res.force_encoding('UTF-8')  # 强制转换为 UTF-8 编码
  end

  # # 示例用法
  # if __FILE__ == $0
  #   # 密钥生成（推荐使用安全的随机生成方式）
  #   key = OpenSSL::Random.random_bytes(32) # AES-256 需要32字节密钥
  #
  #   # 随机生成 IV（每次加密必须不同！）
  #   iv = OpenSSL::Random.random_bytes(16) # AES-CBC 需要16字节 IV
  #
  #   original_text = "Hello, "
  #   puts "原始文本: #{original_text}"
  #
  #   # 加密
  #   encrypted = aes_encrypt(original_text, key, iv)
  #   puts "加密结果: #{encrypted}"
  #
  #   # 解密
  #   decrypted = aes_decrypt(encrypted, key)
  #   puts "解密结果: #{decrypted}"
  # end
end
