require 'evoasm/core_ext/ffi'

module Evoasm
  module Libevoasm
    class SearchParams < FFI::Struct
      layout :insts, :pointer,
             :params, :pointer,
             :domains, [:pointer, Arch::MAX_PARAMS],
             :min_adf_size, :adf_size,
             :max_adf_size, :adf_size,
             :min_kernel_size, :kernel_size,
             :max_kernel_size, :kernel_size,
             :recur_limit, :uint32,
             :insts_len, :uint16,
             :params_len, :uint8,
             :pop_size, :uint32,
             :mut_rate, :uint32,
             :adf_input, ADFInput,
             :adf_output, ADFOutput,
             :seed64, [:uint64, 16],
             :seed32, [:uint32, 4],
             :max_loss, :loss

      def initialize(architecture, parameters)
        super()

        clear

        case architecture
        when X64
          inst_id_enum_type = Libevoasm.enum_type :x64_inst_id
          param_id_enum_type = Libevoasm.enum_type :x64_param_id
        else
          raise
        end

        self[:mut_rate] = parameters.mutation_rate

        insts = FFI::MemoryPointer.new :uint16, parameters.instructions.size
        insts.write_array_of_uint16 inst_id_enum_type.values(parameters.instructions)
        self[:insts] = insts
        self[:insts_len] = parameters.instructions.size

        #p @inst_array
        #p parameters.instructions
        #p inst_id_enum_type.values(parameters.instructions)

        %i(kernel_size adf_size).each do |attr|
          size = parameters.send attr
          min_attr_name = :"min_#{attr}"
          max_attr_name = :"max_#{attr}"
          case size
          when Range
            self[min_attr_name] = size.min
            self[max_attr_name] = size.max
          when Integer
            self[min_attr_name] = size
            self[max_attr_name] = size
          else
            raise ArgumentError, "kernel size must be range or integer (have #{size.class})"
          end
        end

        params = FFI::MemoryPointer.new :uint8, parameters.parameters.size
        params.write_array_of_uint8 param_id_enum_type.values parameters.parameters
        self[:params] = params
        self[:params_len] = parameters.parameters.size

        self[:pop_size] = parameters.population_size
        self[:mut_rate] = (parameters.mutation_rate * Libevoasm::INT32_MAX).to_i
        self[:seed32].to_ptr.write_array_of_uint32 parameters.seed32
        self[:seed64].to_ptr.write_array_of_uint64 parameters.seed64
        self[:recur_limit] = parameters.recur_limit

        domains = convert_domains parameters.domains, param_id_enum_type
        domains_ary = self[:domains]
        domains.size.times do |i|
          domains_ary[i] = domains[i].to_ptr
        end

        input_examples = parameters.examples.keys.map { |k| Array(k) }
        output_examples = parameters.examples.values.map { |k| Array(k) }

        self[:adf_input] = Libevoasm::ADFInput.new input_examples
        self[:adf_output] = Libevoasm::ADFOutput.new output_examples
      end

      private
      def convert_domains(domains, enum_type)
        domain_values, _, _ = Libevoasm.enum_hash_to_array(domains, enum_type, :n_params, FFI::Pointer::NULL) do |domain|
          Libevoasm::Domain.for domain
        end
        domain_values
      end

    end
  end
end