#!/usr/bin/ruby

# Created by Vyacheslav Khorkov on 17.07.2020.
# Copyright © 2020 Vyacheslav Khorkov. All rights reserved.

require 'set'

# Constants
OUTPUT_BULLET = "•"
OUTPUT_BULLET_COLORS = [9, 3, 2, 75, 99]

# Help information
HELP_COMMANDS = ["-h", "--help", "help"]
def putsHelp()
  puts "Tiny utility for visualise Pod dependencies tree.".colorize(2)
  puts "Skips subspecs and pods without versions.".colorize(2)
  puts "Help options: #{HELP_COMMANDS}"
  puts "  • 1st argument will be used as root Pod".colorize(3)
  puts "  • 2nd one is path to Podfile (pwd by default)\n".colorize(3)
  puts "ruby PodTree.rb A Podfile.lock".colorize(3)
  puts "Podfile.lock:".colorize(2) + "         Output:".colorize(2)
  margin = "           "
  puts "- A (1.0.0)" + margin + "•".colorize(9) + " A"
  puts "- B (1.0.0):" + margin + " •".colorize(3) + " D"
  puts "  - A (= 1.0.0)" + margin + "•".colorize(2) + " C"
  puts "  - C (= 1.0.0)" + margin + "  •".colorize(75) + " B"
  puts "  - D (= 1.0.0)" + margin + "•".colorize(2) + " E"
  puts "- C (1.0.0):"
  puts "  - A (= 1.0.0)"
  puts "  - D (= 1.0.0)"
  puts "- D (1.0.0):"
  puts "  - A (= 1.0.0)"
  puts "- E (1.0.0):"
  puts "  - A (= 1.0.0)"
  puts "  - D (= 1.0.0)"
end

# Class describing Pod
class Pod
  attr_reader :name, :parents, :children
  def initialize(name)
    @name = name
    @parents = Set.new; @children = Set.new
  end
end

# Parsing
def parsePodfile(pod_file)
  currentPod = nil
  pods = Hash.new
  File.readlines(pod_file).each do |line|
    next if line.start_with?("PODS:")
    break if line.start_with?("DEPENDENCIES:")

    if line.start_with?("  -") # Parents
      parts = line.split(" ")
      name = parts[1].split("/")[0]

      unless pods.has_key?(name)
        pods[name] = Pod.new(name)
      end
      currentPod = pods[name]
    elsif line.start_with?("    -") # Childs
      parts = line.split(" ")
      next if parts.count == 2 # Skip without version
      name = parts[1].split("/")[0]

      unless pods.has_key?(name)
        pods[name] = Pod.new(name)
      end
      pods[name].parents.add(currentPod)
      currentPod.children.add(pods[name])
    end
  end
  return pods
end

# Create dependecies tree
def buildTree(pods, pod_name)
  root = Pod.new(pod_name)
  last = { root.name => root }

  names = pods[pod_name].parents.map { |pod| pod.name }.to_set
  names.delete(pod_name)
  while !names.empty? do
    step = Set.new

    # Calculate step
    names.each { |name|
      podNames = pods[name].children.map { |pod| pod.name }.to_set
      podNames.delete(name) # Remove subspecs intersection
      if podNames.intersection(names).empty?
        step.add(name)
      end
    }
    if step.empty?
      STDERR.puts("Can't build a step.".colorize(9))
      exit(false)
    end

    # Build tree level
    new = Hash.new
    step.each { |name|
      pods[name].children.each { |pod|
        if last.has_key?(pod.name)
          newPod = Pod.new(name)
          last[pod.name].children.add(newPod)
          new[name] = newPod
        end
      }
    }
    last = new
    names.subtract(step)
  end
  return root
end

# Colorize output
class String
  def colorize(color_code)
    "\e[38;5;#{color_code}m#{self}\e[0m"
  end
end

# Output tree recursively
def putsTree(root, level = 0, bullet, colors)
  if level != 0
    prefix = "  " * (level - 1) + bullet
    color = colors[(level - 1) % colors.count]
    puts prefix.colorize(color) + " " + root.name
  end
  root.children.each { |pod|
    putsTree(pod, level + 1, bullet, colors)
  }
end

# === Main ===
# Check if 1st argument is help
if HELP_COMMANDS.include?ARGV[0]
  putsHelp()
  exit(false)
end

# Get input arguments
POD_NAME = ARGV[0]
POD_FILE = ARGV[1] || "Podfile.lock"

# Parse Podfile
PODS = parsePodfile(POD_FILE)
unless PODS.has_key?(POD_NAME)
  STDERR.puts("Can't find pod name.".colorize(9))
  putsHelp()
  exit(false)
end

# Build and output tree
TREE = buildTree(PODS, POD_NAME)
putsTree(TREE, 1, OUTPUT_BULLET, OUTPUT_BULLET_COLORS)
