# -*- coding: utf-8; -*-
module Subak
  module Utility
    def self.uniqid
      require 'digest'
      Digest::MD5.hexdigest('tk84' + Time.now.instance_eval { '%s.%06d' % [strftime('%Y%m%d%H%M%S'), usec] })
    end

    def self.shorten_hash hex
      raise ArgumentError, 'hex include unavailable characters' if hex =~ /[^0-9a-f]/

      chars16 = %w(0 1 2 3 4 5 6 7 8 9 a b c d e f)
      chars62 = chars16 +
        %w(g h i j k l m n o p q r s t u v w x y z) +
        %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)

      chars16Hash = Hash[*([chars16, [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]].transpose.flatten)]

      int = 0
      hex.each_char.to_a.reverse.each_with_index do |c, i|
        intC = chars16Hash[c]
        i.times do
          intC *= 16
        end

        int += intC
      end

      hex62 = ''
      until int == 0 do
        intC = int % 62
        int /= 62

        hex62 = hex62 + chars62[intC]
      end

      hex62
    end
  end
end
