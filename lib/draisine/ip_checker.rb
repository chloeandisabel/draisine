require "ipaddr"

module Draisine
  class IpChecker
    attr_reader :ip_ranges
    def initialize(ip_ranges)
      @ip_ranges = ip_ranges.map {|net| IPAddr.new(net) }
    end

    def check(ip)
      addr = IPAddr.new(ip)
      ip_ranges.any? {|range| range.include?(addr) }
    end
  end
end
