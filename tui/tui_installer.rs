use std::{
    io::{self, stdout, Stdout},
    thread,
    time::Duration,
};

use color_eyre::{eyre::eyre, Result};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{
        disable_raw_mode, enable_raw_mode, EnterAlternateScreen,
        LeaveAlternateScreen,
    },
};
use ratatui::{
    prelude::{CrosstermBackend, Frame, Terminal},
    style::{Color, Style, Stylize},
    widgets::{
        block::Title, Block, Borders, Paragraph,
    },
};
use tui_input::{backend::crossterm::EventHandler, Input};

struct App {
    input: Input,
    message: String,
    should_quit: bool,
}

impl App {
    fn new() -> App {
        App {
            input: Input::default().with_cursor_attribute(ratatui::style::Modifier::REVERSED),
            message: String::from("Enter your desired username:"),
            should_quit: false,
        }
    }
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> Result<()> {
    loop {
        terminal.draw(|f| ui(f, app))?;

        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Enter => {
                            let username = app.input.value().trim();
                            if !username.is_empty() {
                                println!("{}", username);
                                app.should_quit = true;
                            } else {
                                app.message = "Username cannot be empty. Please try again:".to_string();
                            }
                        }
                        KeyCode::Esc => {
                            app.should_quit = true;
                        }
                        _ => {
                            app.input.handle_event(&Event::Key(key));
                        }
                    }
                }
            }
        }

        if app.should_quit {
            break;
        }
    }
    Ok(())
}

fn ui(f: &mut Frame, app: &mut App) {
    let size = f.size();
    let width = size.width;
    let height = size.height;

    let block = Block::default()
        .title(Title::from("Archfast TUI").alignment(ratatui::prelude::Alignment::Center))
        .borders(Borders::all())
        .border_style(Style::default().fg(Color::Cyan));

    let inner = block.inner(size);
    f.render_widget(block, size);

    let message_paragraph = Paragraph::new(app.message.as_str())
        .style(Style::default().fg(Color::White))
        .alignment(ratatui::prelude::Alignment::Center)
        .wrap(ratatui::widgets::Wrap { trim: true });

    f.render_widget(message_paragraph, inner);
    
    let input_widget = Paragraph::new(app.input.value())
        .style(Style::default().fg(Color::Yellow))
        .block(Block::default().borders(Borders::BOTTOM).border_style(Style::default().fg(Color::White)))
        .alignment(ratatui::prelude::Alignment::Center);

    let input_area = ratatui::prelude::Rect {
        x: inner.x,
        y: inner.y + 2,
        width: inner.width,
        height: 1,
    };
    f.render_widget(input_widget, input_area);

    f.set_cursor(
        input_area.x + app.input.cursor() as u16,
        input_area.y,
    );
}

fn main() -> Result<()> {
    enable_raw_mode()?;
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Error: {:?}", err);
        return Err(eyre!(err));
    }

    Ok(())
}
