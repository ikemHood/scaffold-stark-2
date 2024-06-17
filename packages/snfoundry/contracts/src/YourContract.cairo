use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
enum SampleEnum {
    enum1: u256,
    enum2: u256,
    enum3: ByteArray,
}

#[derive(Drop, Serde, starknet::Store)]
struct SampleStruct {
    id: u256,
    name: ByteArray,
    // status: SampleEnum,
}

#[derive(Drop, Serde, starknet::Store)]
struct SampleNestedStruct {
    user: ContractAddress,
    data: SampleStruct,
    status: SampleEnum,
}

#[starknet::interface]
pub trait IYourContract<TContractState> {
    fn gretting(self: @TContractState) -> ByteArray;
    fn set_gretting(ref self: TContractState, new_greeting: ByteArray, amount_eth: u256);
    fn withdraw(ref self: TContractState);
    fn premium(self: @TContractState) -> bool;
    fn test_simple_enum_read(self: @TContractState) -> SampleEnum;
    fn test_simple_enum_write(ref self: TContractState, sample_enum: SampleEnum);
    fn test_struct_read(self: @TContractState) -> SampleStruct;
    fn test_struct_write(ref self: TContractState, sample_struct: SampleStruct);
    fn test_nested_struct_read(self: @TContractState) -> SampleNestedStruct;
    fn test_nested_struct_write(ref self: TContractState, sample_nested_struct: SampleNestedStruct);

    fn test_write_span_felt(ref self: TContractState, span: Span<felt252>);
    fn test_write_span_u256(ref self: TContractState, span: Span<u256>);
    fn test_write_span_bool(ref self: TContractState, span: Span<bool>);
    fn test_write_span_address(ref self: TContractState, span: Span<ContractAddress>);
    fn test_write_span_byte_array(ref self: TContractState, span: Span<ByteArray>);

    // special
    fn test_double_input_span(ref self: TContractState, span1: Span<u256>, span2: Span<u256>);

    // test reads
    fn get_last_span_data_felt(self: @TContractState) -> (felt252, felt252);
    fn get_last_span_data_u256(self: @TContractState) -> (felt252, u256);
    fn get_last_span_data_bool(self: @TContractState) -> (felt252, bool);
    fn get_last_span_data_address(self: @TContractState) -> (felt252, ContractAddress);
    fn get_last_span_data_byte_array(self: @TContractState) -> (felt252, ByteArray);

    fn test_read_double_input_span(ref self: TContractState) -> (u256, u256);
}

#[starknet::contract]
mod YourContract {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use starknet::{get_caller_address, get_contract_address};
    use super::{ContractAddress, IYourContract, SampleEnum, SampleNestedStruct, SampleStruct};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    const ETH_CONTRACT_ADDRESS: felt252 =
        0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        GreetingChanged: GreetingChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct GreetingChanged {
        #[key]
        greeting_setter: ContractAddress,
        #[key]
        new_greeting: ByteArray,
        premium: bool,
        value: u256,
    }

    #[storage]
    struct Storage {
        eth_token: IERC20CamelDispatcher,
        greeting: ByteArray,
        premium: bool,
        total_counter: u256,
        user_gretting_counter: LegacyMap<ContractAddress, u256>,
        sample_enum: SampleEnum,
        sample_struct: SampleStruct,
        sample_nested_struct: SampleNestedStruct,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        test_last_write_span_length: felt252,
        test_2nd_last_item_span_felt: felt252,
        test_2nd_last_item_span_u256: u256,
        test_2nd_last_item_span_bool: bool,
        test_2nd_last_item_span_address: ContractAddress,
        test_2nd_last_item_span_byte_array: ByteArray,
        test_2nd_last_item_span_contract_address: ContractAddress,
        test_double_input_span_last_2nd_item1: u256,
        test_double_input_span_last_2nd_item2: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let eth_contract_address = ETH_CONTRACT_ADDRESS.try_into().unwrap();
        self.eth_token.write(IERC20CamelDispatcher { contract_address: eth_contract_address });
        self.greeting.write("Building Unstoppable Apps!!!");
        self.ownable.initializer(owner);
        self.sample_enum.write(SampleEnum::enum1(1));
    }

    #[abi(embed_v0)]
    impl YourContractImpl of IYourContract<ContractState> {
        fn gretting(self: @ContractState) -> ByteArray {
            self.greeting.read()
        }

        fn set_gretting(ref self: ContractState, new_greeting: ByteArray, amount_eth: u256) {
            self.greeting.write(new_greeting);
            self.total_counter.write(self.total_counter.read() + 1);
            let user_counter = self.user_gretting_counter.read(get_caller_address());
            self.user_gretting_counter.write(get_caller_address(), user_counter + 1);

            if amount_eth > 0 {
                self
                    .eth_token
                    .read()
                    .transferFrom(get_caller_address(), get_contract_address(), amount_eth);
                self.premium.write(true);
            } else {
                self.premium.write(false);
            }

            self
                .emit(
                    GreetingChanged {
                        greeting_setter: get_caller_address(),
                        new_greeting: self.greeting.read(),
                        premium: true,
                        value: 100,
                    }
                );
        }

        fn withdraw(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let balance = self.eth_token.read().balanceOf(get_contract_address());
            self.eth_token.read().transfer(self.ownable.owner(), balance);
        }

        fn premium(self: @ContractState) -> bool {
            self.premium.read()
        }
        fn test_simple_enum_read(self: @ContractState) -> SampleEnum {
            self.sample_enum.read()
        }
        fn test_simple_enum_write(ref self: ContractState, sample_enum: SampleEnum) {
            self.sample_enum.write(sample_enum);
        }
        fn test_struct_read(self: @ContractState) -> SampleStruct {
            self.sample_struct.read()
        }
        fn test_struct_write(ref self: ContractState, sample_struct: SampleStruct) {
            self.sample_struct.write(sample_struct);
        }
        fn test_nested_struct_read(self: @ContractState) -> SampleNestedStruct {
            self.sample_nested_struct.read()
        }
        fn test_nested_struct_write(
            ref self: ContractState, sample_nested_struct: SampleNestedStruct
        ) {
            self.sample_nested_struct.write(sample_nested_struct);
        }

        fn test_write_span_felt(ref self: ContractState, mut span: Span<felt252>) {
            self.test_last_write_span_length.write(span.len().into());

            // get second item with loop like in previous function and pop;
            loop {
                if span.len() == 2 {
                    let second_item = *span.pop_back().unwrap();
                    self.test_2nd_last_item_span_felt.write(second_item);
                    break;
                }
                let useless_item = *span.pop_front().unwrap();
            };
        }

        fn test_write_span_u256(ref self: ContractState, mut span: Span<u256>) {
            self.test_last_write_span_length.write(span.len().into());

            // get second item with loop like in previous function and pop;
            loop {
                if span.len() == 2 {
                    let second_item = *span.pop_front().unwrap();
                    self.test_2nd_last_item_span_u256.write(second_item);
                    break;
                }
                let useless_item = *span.pop_front().unwrap();
            };
        }

        fn test_write_span_bool(ref self: ContractState, mut span: Span<bool>) {
            self.test_last_write_span_length.write(span.len().into());

            // get second item with loop like in previous function and pop;
            loop {
                if span.len() == 2 {
                    let second_item = *span.pop_front().unwrap();
                    self.test_2nd_last_item_span_bool.write(second_item);
                    break;
                }
                let useless_item = *span.pop_front().unwrap();
            };
        }

        fn test_write_span_address(ref self: ContractState, mut span: Span<ContractAddress>) {
            self.test_last_write_span_length.write(span.len().into());

            // get second item with loop like in previous function and pop;
            loop {
                if span.len() == 2 {
                    let second_item = *span.pop_front().unwrap();
                    self.test_2nd_last_item_span_address.write(second_item);
                    break;
                }
                let useless_item = *span.pop_front().unwrap();
            };
        }

        fn test_write_span_byte_array(ref self: ContractState, mut span: Span<ByteArray>) {
            self.test_last_write_span_length.write(span.len().into());
        // only write the length of the string array

        // get second item with loop like in previous function and pop;
        // loop {
        //     if span.len() == 2 {
        //         let mut second_item = *span.pop_front().unwrap();
        //         self.test_2nd_last_item_span_byte_array.write(second_item);
        //         break;
        //     }
        //     let useless_item = *span.pop_front().unwrap();
        // };
        }

        fn test_double_input_span(
            ref self: ContractState, mut span1: Span<u256>, mut span2: Span<u256>
        ) {
            // only write the length of the string array

            // get second item with loop like in previous function and pop;
            loop {
                if span1.len() == 2 {
                    let mut second_item = *span1.pop_front().unwrap();
                    let mut second_item2 = *span2.pop_front().unwrap();
                    self.test_double_input_span_last_2nd_item1.write(second_item);
                    self.test_double_input_span_last_2nd_item2.write(second_item2);
                    break;
                }
                let useless_item = *span1.pop_front().unwrap();
                let useless_item2 = *span2.pop_front().unwrap();
            };
        }

        fn test_read_double_input_span(ref self: ContractState) -> (u256, u256) {
            let last_2nd_item1 = self.test_double_input_span_last_2nd_item1.read();
            let last_2nd_item2 = self.test_double_input_span_last_2nd_item2.read();
            (last_2nd_item1, last_2nd_item2)
        }

        fn get_last_span_data_felt(self: @ContractState) -> (felt252, felt252) {
            let last_span_length = self.test_last_write_span_length.read();
            let second_last_item = self.test_2nd_last_item_span_felt.read();
            (last_span_length, second_last_item)
        }

        fn get_last_span_data_u256(self: @ContractState) -> (felt252, u256) {
            let last_span_length = self.test_last_write_span_length.read();
            let second_last_item = self.test_2nd_last_item_span_u256.read();
            (last_span_length, second_last_item)
        }

        fn get_last_span_data_bool(self: @ContractState) -> (felt252, bool) {
            let last_span_length = self.test_last_write_span_length.read();
            let second_last_item = self.test_2nd_last_item_span_bool.read();
            (last_span_length, second_last_item)
        }

        fn get_last_span_data_address(self: @ContractState) -> (felt252, ContractAddress) {
            let last_span_length = self.test_last_write_span_length.read();
            let second_last_item = self.test_2nd_last_item_span_address.read();
            (last_span_length, second_last_item)
        }

        fn get_last_span_data_byte_array(self: @ContractState) -> (felt252, ByteArray) {
            let last_span_length = self.test_last_write_span_length.read();
            let second_last_item = self.test_2nd_last_item_span_byte_array.read();
            (last_span_length, second_last_item)
        }
    }
}
