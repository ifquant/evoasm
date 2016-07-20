require_relative 'test_helper'

class X64Test < Minitest::Test
  def setup
    @x64 = Evoasm::X64.new
  end

  def test_features
    features = @x64.features
    refute_empty features
    assert features.all? {|i| i.is_a? Symbol}
    if RUBY_PLATFORM =~ /linux/
      cpu_info = File.read '/proc/cpuinfo'
      [:cx8, :cmov, :mmx, :sse, :sse2, :pclmulqdq, :ssse3, :fma, :cx16, :sse4_1,
       :sse4_2, :movbe, :popcnt, :aes, :avx, :f16c, :rdrand, :lahf_lm, :bmi1, :avx2, :bmi2].each do |feature|
        assert_equal features.include?(feature), !!(cpu_info =~ /\b#{feature}\b/)
      end
    end
  end

  def test_instructions
    search_insts = @x64.instructions :xmm, :gp, :rflags, search: true
    assert_equal search_insts, @x64.instructions(:xmm, :gp, :rflags, search: true, operand_types: [:reg, :imm, :rm])
    refute_empty search_insts
    refute_includes search_insts, :jmp_rel32
    refute_includes search_insts, :call_rm32
    assert_includes search_insts, :xor_rax_imm32
    assert_includes search_insts, :vfmadd213pd_xmm_xmm_xmmm128

    gp_insts = @x64.instructions :gp, :rflags
    refute_empty gp_insts
    assert_includes gp_insts, :xor_rax_imm32
    refute_includes gp_insts, :vfmadd213pd_xmm_xmm_xmmm128

    xmm_insts = @x64.instructions :xmm
    refute_empty xmm_insts
    refute_includes xmm_insts, :jmp_rel32
    refute_includes xmm_insts, :xor_rax_imm32
    assert_includes xmm_insts, :vfmadd213pd_xmm_xmm_xmmm128

  end

  def test_rm_reg_reg
    assert_disassembles_to 'add rax, rbx', :add_r64_rm64,
      reg0: :a, reg1: :b
    assert_disassembles_to 'add r11, r12', :add_r64_rm64,
      reg0: :r11, reg1: :r12
    assert_disassembles_to 'add eax, ebx', :add_r32_rm32,
      reg0: :a, reg1: :b
    assert_disassembles_to 'add ax, bx', :add_r16_rm16,
      reg0: :a, reg1: :b
  end

  def test_rm_reg_base
    assert_disassembles_to 'add rax, qword ptr [rbx]', :add_r64_rm64,
      reg0: :a, reg_base: :b
    assert_disassembles_to 'add r11, qword ptr [r12]', :add_r64_rm64,
      reg0: :r11, reg_base: :r12
    assert_disassembles_to 'add eax, dword ptr [rbx]', :add_r32_rm32,
      reg0: :a, reg_base: :b
    assert_disassembles_to 'add ax, word ptr [rbx]', :add_r16_rm16,
      reg0: :a, reg_base: :b

    # reg1 should be ignored
    assert_disassembles_to 'add eax, dword ptr [rbx]', :add_r32_rm32,
      reg0: :a, reg1: :c, reg_base: :b
  end

  def test_rm_reg_base32
    assert_disassembles_to 'add rax, dword ptr [ebx]', :add_r64_rm64,
      reg0: :a, reg_base: :b, address_size: 32

    assert_disassembles_to 'add eax, dword ptr [ebx]', :add_r32_rm32,
      reg0: :a, reg_base: :b, address_size: 32
  end

  def test_rm_reg_sib
    assert_disassembles_to 'add rax, qword ptr [rbx + rcx*4]', :add_r64_rm64,
      reg0: :a, reg_base: :b, reg_index: :c, scale: 4
    assert_disassembles_to 'add rax, qword ptr [rbx + rcx]', :add_r64_rm64,
      reg0: :a, reg_base: :b, reg_index: :c, scale: 1
    assert_disassembles_to 'add rax, qword ptr [rbx + rcx*8]', :add_r64_rm64,
      reg0: :a, reg_base: :b, reg_index: :c, scale: 8

    assert_disassembles_to 'add r10, qword ptr [r11 + r12*4]', :add_r64_rm64,
      reg0: :r10, reg_base: :r11, reg_index: :r12, scale: 4

  end

  def test_mi
    assert_disassembles_to 'add rax, 0xa', :add_rm64_imm8,
      reg0: :a, imm0: 0xa

    assert_disassembles_to 'add qword ptr [rax], 0xa', :add_rm64_imm8,
      reg_base: :a, imm0: 0xa
  end

  def test_vex
    assert_assembles_to "\xC5\xF5\xEC\xC2", :vpaddsb_ymm_ymm_ymmm256,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2, force_long_vex?: false
    assert_assembles_to "\xC4\xE1u\xEC\xC2", :vpaddsb_ymm_ymm_ymmm256,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2, force_long_vex?: true
    assert_disassembles_to 'vpaddsb ymm0, ymm1, ymm2', :vpaddsb_ymm_ymm_ymmm256,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2
    assert_disassembles_to 'vpaddsb ymm0, ymm1, ymm2', :vpaddsb_ymm_ymm_ymmm256,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2, force_long_vex?: true

    assert_assembles_to "\xC5\xF5\xEC\xC2", :vpaddsb_ymm_ymm_ymmm256,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2
    assert_disassembles_to 'vpaddusb xmm0, xmm1, xmm2', :vpaddusb_xmm_xmm_xmmm128,
      reg0: :xmm0, reg1: :xmm1, reg2: :xmm2
    assert_assembles_to "\xC5\xF8\x5A\xCA", :vcvtps2pd_xmm_xmmm64,
      reg0: :xmm1, reg1: :xmm2
    assert_assembles_to "\xC5\xEA\x5A\xCB", :vcvtss2sd_xmm_xmm_xmmm32,
      reg0: :xmm1, reg1: :xmm2, reg2: :xmm3

    assert_assembles_to "\xC4\xE3\x79\x1D\xD1\x00", :vcvtps2ph_xmmm64_xmm_imm8,
      reg0: :xmm1, reg1: :xmm2, imm0: 0x0
  end

end
