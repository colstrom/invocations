#! /usr/bin/env ruby
# -*- ruby -*-

require_relative '../lib/invocations'

class Invocation
  def self.test
    {
      '&lambda' => (self.new(&lambda { |am1, am2, ao = nil, *ar, km1:, km2:, ko: nil, **kr| [am1, am2, ao, ar, km1, km2, ko, kr] })),
      'lambda'  => (self.new(lambda  { |am1, am2, ao = nil, *ar, km1:, km2:, ko: nil, **kr| [am1, am2, ao, ar, km1, km2, ko, kr] })),
      '&proc'   => (self.new(&proc   { |am1, am2, ao = nil, *ar, km1:, km2:, ko: nil, **kr| [am1, am2, ao, ar, km1, km2, ko, kr] })),
      'proc'    => (self.new(proc    { |am1, am2, ao = nil, *ar, km1:, km2:, ko: nil, **kr| [am1, am2, ao, ar, km1, km2, ko, kr] })),
      '&block'  => (self.new         { |am1, am2, ao = nil, *ar, km1:, km2:, ko: nil, **kr| [am1, am2, ao, ar, km1, km2, ko, kr] }),
    }
  end
end

abort unless 1 == Invocation
                    .test
                    .map { |style, function| [style, function.(1).(2).(3).(4, 5).(km1: 6).(km2: 7)] }
                    .to_h
                    .values
                    .uniq
                    .length
