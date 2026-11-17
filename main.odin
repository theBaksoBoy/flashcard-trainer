package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:math/rand"



cards_left_in_session: int
endless_mode: bool

cards_file_line_contains_card: [dynamic]bool
cards_in_file_order: [dynamic]Card
cards_in_session_order: [dynamic]^Card

Card :: struct {
    front: string,
    back: string,
    index_in_deck: int,
    indices_pushed_back: int,
    extra_info: string,
}



main :: proc() {
    
    // ask user how many cards they want to go through in the session
    GetSessionCardCount()

    LoadCards()

    show_back := false

    fmt.println("----------------------------------------------------------------------")
    fmt.println("\n\n\n\n\n\n\n\n\n\n")
    for {
        fmt.print("\x1b[10A") // go up 10
        fmt.print("\x1b[2K\r") // clear line and go to start
        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start

        fmt.print(fmt.tprintf("    %s", cards_in_session_order[0].front))

        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start
        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start

        if show_back {
            fmt.print(fmt.tprintf("    %s", cards_in_session_order[0].back))
        }

        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start
        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start

        if show_back && cards_in_session_order[0].extra_info != "x" {
            fmt.print(fmt.tprintf("    %s", cards_in_session_order[0].extra_info))
        }

        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start
        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start

        if !endless_mode {
            fmt.print(fmt.tprintf("%d cards left", cards_left_in_session))
        }
        
        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start

        if show_back {
            fmt.print("\"y\"/\"n\" for if you knew the back or not. \"q\" to save and quit.")
        }
        else {
            fmt.print("Enter to continue. \"q\" to save and quit.")
        }

        fmt.print("\x1b[1B\x1b[2K\r") // go down one, clear line, go to start


        buf: [512]byte
        bytes_read, _ := os.read(os.stdin, buf[:])
        s := string(buf[:bytes_read-1])


        // quit when q is inputted
        if s == "q" do break

        // move card back when y or n is inputted
        if (s == "y" || s == "n") && show_back {
            
            new_float_position := f32(cards_in_session_order[0].indices_pushed_back)

            if s == "y" do new_float_position *= 2
            if s == "n" do new_float_position /= 8

            // clamp value to card count before applying the random multiplier
            new_float_position = min(new_float_position, f32(len(cards_in_session_order)-1))

            // randomly set the value to 90%-110% of itself to make cards answered in sequence not later appear in the same sequence
            new_float_position *= rand.float32() * 0.2 + 0.9
            
            new_position := int(new_float_position + 0.5)

            // clamp value to allowed indices
            new_position = max(new_position, 1)
            new_position = min(new_position, len(cards_in_session_order)-1)


            // move the card to its new index and assign that value to the card

            cards_in_session_order[0].indices_pushed_back = new_position

            temp := cards_in_session_order[0]
            for i in 0 ..< new_position {
                cards_in_session_order[i] = cards_in_session_order[i+1]
            }
            cards_in_session_order[new_position] = temp
        }
        else if show_back do continue // if no valid input was given when the back is shown then ask for input again


        // reduce cards left count and quit once it hits zero, if it isn't in endless mode
        if !endless_mode {
            if show_back && !endless_mode {
                cards_left_in_session -= 1
            }

            if cards_left_in_session <= 0 {
                break
            }
        }
        
        show_back = !show_back
    }

    SaveCards()
}



GetSessionCardCount :: proc() {
    
    fmt.println("Input the card count for this session. Input nothing to enter endless mode.")

    for { // loop until valid input
        buffer: [512]byte
        bytes_read, _ := os.read(os.stdin, buffer[:])

        // detects if nothing was inputted
        if buffer[0] == byte('\n') {
            endless_mode = true
            return
        }

        s := string(buffer[:bytes_read-1])

        n, ok := strconv.parse_int(s)
        if !ok {
            fmt.println("Not a valid number. Try again.")
            continue
        }

        if n < 1 {
            fmt.println("Number must be at least 1. Try again.")
            continue
        }

        endless_mode = false
        cards_left_in_session = n
        return
    }
}



LoadCards :: proc() {
    
    CardFields :: enum {
        FRONT,
        BACK,
        INDEX_IN_DECK,
        INDICES_PUSHED_BACK,
        EXTRA_INFO,
    }

    ParseToInt :: proc(s: string) -> int {
        n, ok := strconv.parse_int(s)
        if !ok {
            fmt.println("Something went wrong when parsing cards.txt. A value that should have been a number wasn't able to be parsed as one. Either a field that was meant to be a number acidentally has other symbols in it, or a field in a card could be missing or have one extra, meaning that every card's field is incorrectly offset.")
            os.exit(1)
        }
        return n
    }

    data, err := os.read_entire_file_from_path("cards.txt", context.allocator)
    defer delete(data)

    if err != os.ERROR_NONE {
        fmt.println("failed to read card.txt")
        os.exit(1)
    }

    cards_file_line_contains_card = make([dynamic]bool)
    cards_in_file_order = make([dynamic]Card)
    cards_in_session_order = make([dynamic]^Card)

    data_length := len(data)
    index_of_data: int = 0 

    current_field_being_analyzed := CardFields.FRONT
    current_card_front: string
    current_card_back: string
    current_card_index_in_deck: int
    current_card_indices_pushed_back: int
    current_card_extra_info: string
    
    for index_of_data < data_length {

        // if the byte is that of \n then it is an empty line
        if data[index_of_data] == byte('\n') {
            append(&cards_file_line_contains_card, false)
            index_of_data += 1
            continue
        }

        // keep going until finding a ~ or \n and get the string between the this and the previous separator
        bytes_counted: int = 0
        for {
            bytes_counted += 1

            if data[index_of_data + bytes_counted] == byte('\n') || data[index_of_data + bytes_counted] == byte('~') {
                field_string := string(data[index_of_data:index_of_data+bytes_counted])

                // save the field into a variable that will be used to create a Card instance
                switch current_field_being_analyzed {
                case .FRONT:
                    current_card_front = field_string
                    current_field_being_analyzed = .BACK

                case .BACK:
                    current_card_back = field_string
                    current_field_being_analyzed = .INDEX_IN_DECK

                case .INDEX_IN_DECK:
                    current_card_index_in_deck = ParseToInt(field_string)
                    current_field_being_analyzed = .INDICES_PUSHED_BACK

                case .INDICES_PUSHED_BACK:
                    current_card_indices_pushed_back = ParseToInt(field_string)
                    current_field_being_analyzed = .EXTRA_INFO

                case .EXTRA_INFO:
                    current_card_extra_info = field_string
                    current_field_being_analyzed = .FRONT

                    // since this is the last field, all the data for a card has been recorded
                    // and an instance of the Card struct can be created and added to the array
                    append(&cards_in_file_order, Card{
                        strings.clone(current_card_front),
                        strings.clone(current_card_back),
                        current_card_index_in_deck,
                        current_card_indices_pushed_back,
                        strings.clone(current_card_extra_info),
                    })
                    append(&cards_file_line_contains_card, true)
                }
                
                index_of_data += bytes_counted + 1
                break
            }
        }
    }

    // the data from cards.txt has now been loaded
    
    // add all the cards to cards_in_session_order
    // the way this is done is pretty ass but fuck you I don't give a swag
    for i in -1 ..< len(cards_in_file_order) {
        for j in 0 ..< len(cards_in_file_order) {
            if cards_in_file_order[j].index_in_deck == i do append(&cards_in_session_order, &cards_in_file_order[j])
        }
    }
}



SaveCards :: proc() {

    // make sure that the saved indices are correct
    for i in 0 ..< len(cards_in_session_order) {
        cards_in_session_order[i].index_in_deck = i
    }

    content_builder := strings.builder_make()
    defer strings.builder_destroy(&content_builder)

    card_index: int = 0
    
    for line_contains_card in cards_file_line_contains_card {
        if line_contains_card {
            strings.write_string(&content_builder, fmt.tprintf(
                "%s~%s~%d~%d~%s\n",
                cards_in_file_order[card_index].front,
                cards_in_file_order[card_index].back,
                cards_in_file_order[card_index].index_in_deck,
                cards_in_file_order[card_index].indices_pushed_back,
                cards_in_file_order[card_index].extra_info,
            ))
            card_index += 1
        }
        else {
            strings.write_string(&content_builder, "\n")
        }
    }

    content := strings.to_string(content_builder)

    err := os.write_entire_file_from_string("cards.txt", content)
    if err != os.ERROR_NONE {
        fmt.println("failed to save cards.txt:", err)
        os.exit(1)
    }
}
